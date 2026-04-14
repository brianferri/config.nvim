local M = {}

---@class GqlVirtualDoc
---@field uri string
---@field version integer

---@class GqlConfig
---@field debounce_ms? integer
---@field string_node_map? table<string, string>
---@field namespace? string

---@class GqlState
---@field timers table<integer, uv.uv_timer_t>
---@field virtual_docs table<integer, GqlVirtualDoc>
---@field ns ?integer

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

    local row, col = table.unpack(vim.api.nvim_win_get_cursor(0))
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
            if result.uri:match("%.graphql$") then
                local host = result.uri:gsub("%.graphql$", "")
                local bufnr = vim.uri_to_bufnr(host)

                if vim.api.nvim_buf_is_valid(bufnr) then
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

                    if state.ns then vim.diagnostic.set(state.ns, bufnr, diagnostics) end
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
---@return string
local function virtual_uri(bufnr)
    return vim.uri_from_bufnr(bufnr) .. ".graphql"
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

---@param bufnr integer
---@param fragments { start_row: integer, text: string }[]
local function sync_lsp(bufnr, fragments)
    local client = ensure_graphql_client(bufnr)
    if not client then return end

    local line_count = vim.api.nvim_buf_line_count(bufnr)
    ---@type string[]
    local lines = {}

    for i = 1, line_count do lines[i] = "" end
    for _, frag in ipairs(fragments) do
        local split = vim.split(frag.text, "\n")
        for i, line in ipairs(split) do
            local idx = frag.start_row + i
            if idx >= 1 and idx <= line_count then
                lines[idx] = line
            end
        end
    end

    local content = table.concat(lines, "\n")
    local uri = virtual_uri(bufnr)

    state.virtual_docs[bufnr] =
        push_virtual_doc(client, uri, content, state.virtual_docs[bufnr])
end

--------------------------------------------------------------------------------
-- Treesitter Processing
--------------------------------------------------------------------------------

---@param bufnr integer
local function collect_fragments(bufnr)
    local parser = get_parser(bufnr)
    if not parser then return {} end
    parser:parse(true)
    ---@type { start_row: integer, text: string }[]
    local fragments = {}

    parser:for_each_tree(function(tree, lang_tree)
        if lang_tree:lang() ~= "graphql" then return end

        local root = tree:root()
        local row = select(1, root:range())

        table.insert(fragments, {
            start_row = row,
            text = vim.treesitter.get_node_text(root, bufnr),
        })
    end)

    return fragments
end

---@param bufnr integer
local function process(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then return end
    local fragments = collect_fragments(bufnr)

    if #fragments == 0 then
        if state.ns then vim.diagnostic.set(state.ns, bufnr, {}) end
        return
    end

    sync_lsp(bufnr, fragments)
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
        local client = vim.lsp.get_clients({ name = "graphql" })[1]
        if not client then
            return callback({ items = {}, isIncomplete = false })
        end

        local bufnr = vim.api.nvim_get_current_buf()
        local uri = virtual_uri(bufnr)

        local cursor = vim.api.nvim_win_get_cursor(0)

        client:request("textDocument/completion", {
            textDocument = { uri = uri },
            position = {
                line = cursor[1] - 1,
                character = cursor[2],
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
            local client = vim.lsp.get_clients({ name = "graphql" })[1]
            local doc = state.virtual_docs[args.buf]
            if client and doc then
                client:notify("textDocument/didClose", {
                    textDocument = { uri = doc.uri },
                })
                state.virtual_docs[args.buf] = nil
            end
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

    register_cmp()
end

return M
