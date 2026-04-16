local M = {}

--[[
uGraphQL: GraphQL-in-strings bridge for Neovim LSP

This module extracts GraphQL treesitter injections from host language files
(php, lua, js/ts, python, etc.) and mirrors them to GraphQL LSP as one or more
virtual GraphQL documents.

How virtual documents are named
  - Default behavior:
      Every injected fragment maps to a URI ending in ".graphql".
      Example: "file:///.../test.php.graphql"
  - Optional per-fragment suffix override:
      Add an inline marker on one of the first 3 lines of the injected block:
        # graphql `.suffix.graphql`
        # graphql `suffix`            -- normalized to ".suffix.graphql"
      This suffix is appended to the host URI so GraphQL project globs can
      route that fragment to a specific schema.
]]

---@class GqlVirtualDoc
---@field uri string
---@field version integer
---@field diagnostics? vim.Diagnostic[]

---@class GqlConfig
---@field debounce_ms? integer
---@field string_node_map? table<string, string>
---@field namespace? string

---@class GqlState
---@field timers table<integer, uv.uv_timer_t>
---@field virtual_docs table<integer, table<string, GqlVirtualDoc>>
---@field ns ?integer
---@field hover_patched? boolean
---@field original_hover? fun(opts?: vim.lsp.buf.hover.Opts)

---@type GqlConfig
local config = {
    debounce_ms = 400,
    namespace = "uGraphQL",
    string_node_map = {
        lua = "string_content",
        php = "heredoc_body",
        javascript = "string_fragment",
        javascriptreact = "string_fragment",
        typescript = "string_fragment",
        tsx = "string_fragment",
        python = "string_content",
        go = "raw_string_literal_content",
        rust = "string_literal",
        -- TODO: Find a way to strip the `\\`
        zig = "multiline_string",
        ruby = "heredoc_content",
    },
}

---@type GqlState
local state = {
    timers = {},
    virtual_docs = {},
    ns = nil,
    hover_patched = false,
    original_hover = nil,
}

local augroup = vim.api.nvim_create_augroup("UniversalGraphQL", { clear = true })

--------------------------------------------------------------------------------
-- Utils
--------------------------------------------------------------------------------

---@param bufnr integer
local function get_parser(bufnr)
    local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
    if not ok then return nil end
    return parser
end

local function cursor_in_graphql()
    local buf = vim.api.nvim_get_current_buf()
    local parser = get_parser(buf)
    if not parser then return false end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local row, col = cursor[1], cursor[2]
    row = row - 1

    local tree = parser:language_for_range({ row, col, row, col })
    return tree and tree:lang() == "graphql"
end

---@param lang string
local function read_injection_queries(lang)
    local files = vim.treesitter.query.get_files(lang, "injections")
    local contents = {}

    for _, path in ipairs(files) do
        local f = io.open(path, "r")
        if f then
            table.insert(contents, f:read("*a"))
            f:close()
        end
    end

    return table.concat(contents, "\n")
end

--------------------------------------------------------------------------------
-- Diagnostics Bridge
--------------------------------------------------------------------------------

---@param bufnr integer
local function refresh_buffer_diagnostics(bufnr)
    if not state.ns then return end

    local diagnostics = {}
    local docs = state.virtual_docs[bufnr] or {}
    for _, doc in pairs(docs) do
        for _, d in ipairs(doc.diagnostics or {}) do
            diagnostics[#diagnostics + 1] = d
        end
    end

    vim.diagnostic.set(state.ns, bufnr, diagnostics)
end

---@param bufnr integer
---@param uri string
---@param diagnostics vim.Diagnostic[]
local function set_uri_diagnostics(bufnr, uri, diagnostics)
    local docs = state.virtual_docs[bufnr]
    if not docs then
        docs = {}
        state.virtual_docs[bufnr] = docs
    end
    local doc = docs[uri]
    if not doc then
        doc = { uri = uri, version = 0 }
        docs[uri] = doc
    end

    doc.diagnostics = diagnostics
    refresh_buffer_diagnostics(bufnr)
end

---@param uri string
---@return boolean
local function is_virtual_graphql_uri(uri)
    local graphql_cfg = vim.lsp.config.graphql
    local filetypes = graphql_cfg and graphql_cfg.filetypes or { "graphql", "gql" }

    for _, filetype in ipairs(filetypes) do
        if type(filetype) == "string" and filetype ~= "" then
            local suffix = "." .. filetype
            if uri:sub(-#suffix) == suffix then
                return true
            end
        end
    end

    return false
end

---@param uri string
---@return integer|nil
local function resolve_virtual_uri_bufnr(uri)
    for candidate, docs in pairs(state.virtual_docs) do
        if docs[uri] and vim.api.nvim_buf_is_valid(candidate) then
            return candidate
        end
    end

    for _, candidate in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(candidate) then
            local host = vim.uri_from_bufnr(candidate)
            local host_len = #host
            if uri:sub(1, host_len) == host then
                local suffix = uri:sub(host_len + 1)
                if suffix:match("^%.[^/]+$") then
                    return candidate
                end
            end
        end
    end

    return nil
end

---@param client vim.lsp.Client
local function attach_lsp_bridge(client)
    local base =
        client.handlers["textDocument/publishDiagnostics"]
        or vim.lsp.handlers["textDocument/publishDiagnostics"]

    client.handlers["textDocument/publishDiagnostics"] =
    ---@param err lsp.ResponseError
    ---@param result any
    ---@param ctx lsp.HandlerContext
    ---@param cfg table
        function(err, result, ctx, cfg)
            if not result or not result.uri then return end
            if is_virtual_graphql_uri(result.uri) then
                local bufnr = resolve_virtual_uri_bufnr(result.uri)

                if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
                    ---@type vim.Diagnostic[]
                    local diagnostics = {}

                    for _, d in ipairs(result.diagnostics or {}) do
                        diagnostics[#diagnostics + 1] = {
                            bufnr = bufnr,
                            lnum = d.range.start.line,
                            col = d.range.start.character,
                            end_lnum = d.range["end"].line,
                            end_col = d.range["end"].character,
                            severity = d.severity,
                            message = d.message,
                            source = d.source or "graphql-lsp",
                        }
                    end

                    set_uri_diagnostics(bufnr, result.uri, diagnostics)
                    return
                end
            end

            return base(err, result, ctx, cfg)
        end
end

--------------------------------------------------------------------------------
-- LSP Sync
--------------------------------------------------------------------------------

---@param bufnr integer
---@param graphql_cfg vim.lsp.Config
---@return string
local function graphql_root(bufnr, graphql_cfg)
    local cwd = vim.uv.cwd() or vim.fn.getcwd()
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name == "" then return cwd end

    local markers = graphql_cfg.root_markers
    local root = type(markers) == "table" and vim.fs.root(name, markers) or nil
    if root then return root end

    local dir = vim.fs.dirname(name)
    return dir ~= "" and dir or cwd
end

---@param bufnr integer
---@return vim.lsp.Client|nil
local function ensure_graphql_client(bufnr)
    local graphql_cfg = vim.lsp.config.graphql
    if not graphql_cfg then
        vim.notify(
            "GraphQL LSP config is missing; cannot start GraphQL language server.",
            vim.log.levels.WARN,
            { title = config.namespace }
        )
        return nil
    end

    local root_dir = graphql_root(bufnr, graphql_cfg)

    for _, client in ipairs(vim.lsp.get_clients({ name = "graphql" })) do
        if client.config.root_dir == root_dir then return client end
    end

    local start_cfg = vim.deepcopy(graphql_cfg)
    start_cfg.root_dir = root_dir

    local client_id = vim.lsp.start(start_cfg, {
        bufnr = bufnr,
        reuse_client = function(client, cfg)
            return client.name == "graphql" and client.config.root_dir == cfg.root_dir
        end,
    })

    if not client_id then return nil end
    local client = vim.lsp.get_client_by_id(client_id)
    if client then attach_lsp_bridge(client) end
    return client
end

---@param bufnr integer
---@param suffix string|nil
---@return string
local function virtual_uri(bufnr, suffix)
    local resolved_suffix = suffix or ".graphql"
    return vim.uri_from_bufnr(bufnr) .. resolved_suffix
end

---@param text string
---@return string|nil
local function extract_virtual_suffix(text)
    local max_lines = 3
    local line_count = 0
    for line in vim.gsplit(text, "\n", { plain = true }) do
        line_count = line_count + 1
        local suffix = line:match("#%s*graphql%s*`([^`]+)`")
        if suffix then
            suffix = suffix:gsub("^%s+", ""):gsub("%s+$", "")
            if suffix == "" then return nil end

            if not suffix:match("%.graphql$") and not suffix:match("%.gql$") then
                suffix = suffix .. ".graphql"
            end
            if not suffix:match("^%.") then
                suffix = "." .. suffix
            end

            return suffix
        end
        if line_count >= max_lines then break end
    end
    return nil
end

---@param client vim.lsp.Client
---@param uri string
---@param content string
---@param doc GqlVirtualDoc|nil
local function push_virtual_doc(client, uri, content, doc)
    if not doc then
        client:notify("textDocument/didOpen", {
            textDocument = {
                uri = uri,
                languageId = "graphql",
                version = 1,
                text = content,
            },
        })
        return { uri = uri, version = 1 }
    end

    doc.version = doc.version + 1

    client:notify("textDocument/didChange", {
        textDocument = {
            uri = uri,
            version = doc.version,
        },
        contentChanges = { { text = content } },
    })

    return doc
end

---@param client vim.lsp.Client
---@param uri string
local function close_virtual_doc(client, uri)
    client:notify("textDocument/didClose", {
        textDocument = { uri = uri },
    })
end

---@param bufnr integer
---@param uri string
---@param docs table<string, GqlVirtualDoc>
---@param client vim.lsp.Client|nil
---@param refresh boolean|nil
local function drop_virtual_doc(bufnr, uri, docs, client, refresh)
    if not docs[uri] then return end
    if client then close_virtual_doc(client, uri) end
    docs[uri] = nil
    if refresh ~= false then
        refresh_buffer_diagnostics(bufnr)
    end
end

---@param bufnr integer
---@param client vim.lsp.Client|nil
local function clear_virtual_docs(bufnr, client)
    local docs = state.virtual_docs[bufnr]
    if not docs then return end

    for _, uri in ipairs(vim.tbl_keys(docs)) do
        drop_virtual_doc(bufnr, uri, docs, client, true)
    end

    state.virtual_docs[bufnr] = nil
end

---@param bufnr integer
---@param fragments GqlFragment[]
local function sync_lsp(bufnr, fragments)
    local client = ensure_graphql_client(bufnr)
    if not client then return end

    local line_count = vim.api.nvim_buf_line_count(bufnr)
    ---@type table<string, string[]>
    local lines_by_uri = {}

    for _, frag in ipairs(fragments) do
        local uri = frag.uri
        if not lines_by_uri[uri] then
            lines_by_uri[uri] = {}
            for i = 1, line_count do
                lines_by_uri[uri][i] = ""
            end
        end

        local split = vim.split(frag.text, "\n")
        for i, line in ipairs(split) do
            local idx = frag.start_row + i
            if idx >= 1 and idx <= line_count then
                lines_by_uri[uri][idx] = line
            end
        end
    end

    local previous_docs = state.virtual_docs[bufnr] or {}
    ---@type table<string, GqlVirtualDoc>
    local next_docs = {}
    state.virtual_docs[bufnr] = next_docs

    for uri, lines in pairs(lines_by_uri) do
        local content = table.concat(lines, "\n")
        next_docs[uri] = push_virtual_doc(client, uri, content, previous_docs[uri])
        previous_docs[uri] = nil
    end

    for _, uri in ipairs(vim.tbl_keys(previous_docs)) do
        drop_virtual_doc(bufnr, uri, previous_docs, client, false)
    end
end

--------------------------------------------------------------------------------
-- Treesitter Processing
--------------------------------------------------------------------------------

---@class GqlFragment
---@field start_row integer
---@field start_col integer
---@field end_row integer
---@field end_col integer
---@field text string
---@field uri string

---@param bufnr integer
---@return GqlFragment[]
local function collect_fragments(bufnr)
    local parser = get_parser(bufnr)
    if not parser then return {} end
    parser:parse(true)
    ---@type GqlFragment[]
    local fragments = {}

    parser:for_each_tree(function(tree, lang_tree)
        if lang_tree:lang() ~= "graphql" then return end

        local root = tree:root()
        local start_row, start_col, end_row, end_col = root:range()
        local text = vim.treesitter.get_node_text(root, bufnr)

        table.insert(fragments, {
            start_row = start_row,
            start_col = start_col,
            end_row = end_row,
            end_col = end_col,
            text = text,
            uri = virtual_uri(bufnr, extract_virtual_suffix(text)),
        })
    end)

    return fragments
end

---@param row integer
---@param col integer
---@param fragments GqlFragment[]
---@return integer, integer, string|nil
local function map_host_position_to_virtual(row, col, fragments)
    for _, frag in ipairs(fragments) do
        local before = row < frag.start_row or (row == frag.start_row and col < frag.start_col)
        local after = row > frag.end_row or (row == frag.end_row and col > frag.end_col)

        if not before and not after then
            if row == frag.start_row then
                return row, math.max(0, col - frag.start_col), frag.uri
            end
            return row, col, frag.uri
        end
    end

    return row, col, fragments[1] and fragments[1].uri or nil
end

---@param bufnr integer
---@return GqlFragment[]
local function process(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then return {} end
    local fragments = collect_fragments(bufnr)

    if #fragments == 0 then
        clear_virtual_docs(bufnr, vim.lsp.get_clients({ name = "graphql" })[1])
        if state.ns then vim.diagnostic.set(state.ns, bufnr, {}) end
        return {}
    end

    sync_lsp(bufnr, fragments)
    return fragments
end

--------------------------------------------------------------------------------
-- Hover Monkey Patching
--------------------------------------------------------------------------------

---@param result lsp.Hover|nil
---@param opts vim.lsp.buf.hover.Opts|nil
local function open_hover_preview(result, opts)
    if not result or not result.contents then return end

    local lines = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
    while #lines > 0 and lines[1]:match("^%s*$") do
        table.remove(lines, 1)
    end
    while #lines > 0 and lines[#lines]:match("^%s*$") do
        table.remove(lines, #lines)
    end
    if vim.tbl_isempty(lines) then return end

    local hover_opts = vim.tbl_deep_extend("force", { focus_id = config.namespace .. "_hover" }, opts or {})
    vim.lsp.util.open_floating_preview(lines, "markdown", hover_opts)
end

---@param opts vim.lsp.buf.hover.Opts|nil
local function hover_in_virtual_graphql(opts)
    local bufnr = vim.api.nvim_get_current_buf()
    local ft = vim.bo[bufnr].filetype
    if not config.string_node_map[ft] or not cursor_in_graphql() then return false end

    local fragments = process(bufnr)
    if #fragments == 0 then return false end

    local client = ensure_graphql_client(bufnr)
    if not client then return false end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local line, character, uri = map_host_position_to_virtual(cursor[1] - 1, cursor[2], fragments)
    if not uri then return false end

    client:request("textDocument/hover", {
        textDocument = { uri = uri },
        position = {
            line = line,
            character = character,
        },
    }, function(err, result)
        if err then return end
        open_hover_preview(result, opts)
    end, bufnr)

    return true
end

local function register_hover_bridge()
    if state.hover_patched then return end
    state.hover_patched = true
    state.original_hover = vim.lsp.buf.hover

    ---@diagnostic disable-next-line: duplicate-set-field
    vim.lsp.buf.hover = function(opts)
        if hover_in_virtual_graphql(opts) then return end
        if state.original_hover then
            return state.original_hover(opts)
        end
    end
end

--------------------------------------------------------------------------------
-- Debounce
--------------------------------------------------------------------------------

---@param bufnr integer
local function debounce(bufnr)
    if state.timers[bufnr] then
        state.timers[bufnr]:stop()
        state.timers[bufnr]:close()
    end

    local timer = vim.uv.new_timer()
    if not timer then return end

    state.timers[bufnr] = timer
    timer:start(config.debounce_ms, 0, vim.schedule_wrap(function()
        process(bufnr)
    end))
end

--------------------------------------------------------------------------------
-- Completion (cmp)
--------------------------------------------------------------------------------

local function register_cmp()
    local ok, cmp = pcall(require, "cmp")
    if not ok then return end

    local source = {}

    function source:is_available() return cursor_in_graphql() end

    function source:get_trigger_characters() return { " ", "(", ":", "@", "{", ",", ".", "$" } end

    function source:get_debug_name() return config.namespace end

    ---@param _ cmp.Context
    ---@param callback function
    function source:complete(_, callback)
        local bufnr = vim.api.nvim_get_current_buf()
        local fragments = process(bufnr)
        if not fragments or #fragments == 0 then
            return callback({ items = {}, isIncomplete = false })
        end

        local client = ensure_graphql_client(bufnr)
        if not client then
            return callback({ items = {}, isIncomplete = false })
        end

        local cursor = vim.api.nvim_win_get_cursor(0)
        local line, character, uri =
            map_host_position_to_virtual(cursor[1] - 1, cursor[2], fragments)
        if not uri then
            return callback({ items = {}, isIncomplete = false })
        end

        client:request("textDocument/completion", {
            textDocument = { uri = uri },
            position = {
                line = line,
                character = character,
            },
            context = { triggerKind = 1 },
        }, function(err, result)
            if err or not result then
                return callback({ items = {}, isIncomplete = false })
            end

            local items = result.items or result

            callback({
                items = items,
                isIncomplete = result.isIncomplete or false,
            })
        end)
    end

    cmp.register_source(config.namespace, source)
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

---@param opts GqlConfig|nil
function M.setup(opts)
    config = vim.tbl_deep_extend("force", config, opts or {})
    state.ns = vim.api.nvim_create_namespace(config.namespace)

    for lang, node in pairs(config.string_node_map) do
        local existing = read_injection_queries(lang)

        if not existing:find("uGraphQL_injection", 1, true) then
            local rule = string.format([[
            ((%s) @injection.content
              (#lua-match? @injection.content "^%%s*#%%s*graphql")
              (#set! injection.language "graphql")
              (#set! injection.include-children))
            ]], node)

            local ok = pcall(vim.treesitter.query.set, lang, "injections", existing .. "\n" .. rule)
            if not ok then
                vim.notify(
                    string.format("Failed to update GraphQL injections for '%s'", lang),
                    vim.log.levels.WARN,
                    { title = config.namespace }
                )
            end
        end
    end

    vim.api.nvim_create_autocmd("BufDelete", {
        group = augroup,
        callback = function(args)
            clear_virtual_docs(args.buf, vim.lsp.get_clients({ name = "graphql" })[1])
        end,
    })

    vim.api.nvim_create_autocmd("LspAttach", {
        group = augroup,
        callback = function(args)
            local client = vim.lsp.get_client_by_id(args.data.client_id)
            if client and client.name == "graphql" then attach_lsp_bridge(client) end
        end,
    })

    vim.api.nvim_create_autocmd({
        "BufEnter",
        "BufFilePost",
        "BufWritePost",
        "TextChanged",
        "TextChangedI",
    }, {
        group = augroup,
        callback = function(args)
            local ft = vim.bo[args.buf].filetype
            if config.string_node_map[ft] then
                debounce(args.buf)
            end
        end,
    })

    register_hover_bridge()
    register_cmp()
end

return M
