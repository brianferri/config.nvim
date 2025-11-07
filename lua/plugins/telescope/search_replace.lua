local Path = require("plenary.path")

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local sorters = require("telescope.sorters")
local previewers = require("telescope.previewers")
local from_entry = require("telescope.from_entry")
local action_state = require("telescope.actions.state")
local preview_utils = require("telescope.previewers.utils")
local entry_display = require("telescope.pickers.entry_display")

local conf = require("telescope.config").values
local devicons = require("nvim-web-devicons")

local ns = vim.api.nvim_create_namespace("SearchReplace")
local M = {}

--- @class SearchReplaceConfig
--- @field context_size integer? Number of context lines around matches.

--- @class ReplaceSpec
--- @field is_replace boolean
--- @field range string
--- @field search string
--- @field replace string
--- @field flags string
--- @field count string -- currently unused

--- @class Hunk
--- @field start integer
--- @field finish integer

--- @alias DiffMetaKind "add"|"del"|"same"

--- @class ReplaceDiffMeta
--- @field kind DiffMetaKind
--- @field text string

--- @class TelescopeReplaceEntry: table
--- @field value string
--- @field ordinal string
--- @field display fun(): string
--- @field path string
--- @field prompt ReplaceSpec
--- @field filename string
--- @field lnum integer|nil
--- @field col integer|nil
--- @field text string|nil

--- @type SearchReplaceConfig
local user_config = {
    context_size = 3,
}

-----------------------------------------------------------
-- Utility
-----------------------------------------------------------

--- Get devicon and highlight group for a file.
--- @param path string
--- @return string icon
--- @return string hl_group
local function get_icon_and_hl(path)
    local filename = vim.fn.fnamemodify(path, ":t")
    local ext = vim.fn.fnamemodify(filename, ":e")
    local icon, hl = devicons.get_icon(filename, ext, { default = true })
    return icon or "", hl or "Normal"
end

--- Read all lines from a file.
--- @param path string
--- @return string[]|nil
local function read_file_lines(path)
    local ok, lines = pcall(vim.fn.readfile, path)
    return ok and lines or nil
end

--- Write lines to a file.
--- @param path string
--- @param lines string[]
--- @return boolean
local function write_file_lines(path, lines)
    local result = vim.fn.writefile(lines, path)
    return result == 0
end

--- Sets up a buffer with TS highlighting
--- @param bufnr integer
--- @param filetype string
--- @param lines string[]
local function setup_buffer(bufnr, filetype, lines)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_set_option_value("filetype", filetype, { buf = bufnr })
    preview_utils.ts_highlighter(bufnr, filetype)
end

-----------------------------------------------------------
-- Parsing
-----------------------------------------------------------

--- Parse a substitute-style prompt
--- @see NeoVimDocs [`:h substitute`](https://neovim.io/doc/user/change.html#%3Asubstitute)
--- @see NeoVimDocs [`:h substitute()`](https://neovim.io/doc/user/vimfn.html#substitute())
--- @param prompt string|nil
--- @return ReplaceSpec
local function parse_prompt_regex(prompt)
    if not prompt or prompt == "" then
        return { is_replace = false, range = "", search = "", replace = "", flags = "", count = "" }
    end

    -- ":s", ":1,3s", ":%s", ":'<,'>s"
    --- @type string|nil
    local range = prompt:match("^:(.-)s")
    if not range then
        return { is_replace = false, range = "", search = prompt, replace = "", flags = "", count = "" }
    end

    local sr_prefix = ":" .. range .. "s"
    if not vim.startswith(prompt, sr_prefix) then
        return { is_replace = false, range = "", search = prompt, replace = "", flags = "", count = "" }
    end

    local sep = prompt:sub(#sr_prefix + 1, #sr_prefix + 1)
    if not sep or sep == "" then
        return { is_replace = false, range = "", search = prompt, replace = "", flags = "", count = "" }
    end

    --- @param start_index integer
    --- @return integer|nil
    local function next_separator(start_index)
        local idx = start_index
        while idx <= #prompt do
            local ch = prompt:sub(idx, idx)
            local prev = prompt:sub(idx - 1, idx - 1)
            if ch == sep and prev ~= "\\" then
                return idx
            end
            idx = idx + 1
        end
        return nil
    end

    -- ? `:s/X`
    -- ?     ^ -> Is the (#sr_prefix + 2)
    local search_start = #sr_prefix + 2
    local search_end = next_separator(search_start)
    if not search_end then
        return { is_replace = false, range = "", search = prompt, replace = "", flags = "", count = "" }
    end

    -- ? Skip the separator
    local replace_start = search_end + 1
    local replace_end = next_separator(replace_start)
    if not replace_end then
        return { is_replace = false, range = range, search = prompt, replace = "", flags = "", count = "" }
    end

    -- ? Skip the separators
    local search = prompt:sub(search_start, search_end - 1)
    local replace = prompt:sub(replace_start, replace_end - 1)

    --- @type string, string
    local flags, count = vim.trim(
        prompt:sub(replace_end + 1)
    ):match("^([a-zA-Z]*)%s*(%d*)$")

    return {
        is_replace = true,
        range = range,
        search = search,
        replace = replace,
        flags = flags or "",
        count = count or ""
    }
end

--- Return a line transformer based on `ReplaceSpec`.
--- @param spec ReplaceSpec
--- @return fun(line: string): string
local function transform_line(spec)
    if not spec.is_replace then
        return function(line) return line end
    end
    return function(line)
        local ok, result = pcall(vim.fn.substitute, line, spec.search, spec.replace, spec.flags)
        if not ok then
            vim.notify(("Invalid substitute pattern: %s"):format(result), vim.log.levels.WARN)
            return line
        end
        return result
    end
end

--- Parse a range specifier like "%", "3", or "2,5" into start/end line numbers.
--- @see LuaDocs [Patterns](https://www.lua.org/manual/5.4/manual.html#6.4.1)
--- @see LuaDocs [`string.match`](https://www.lua.org/manual/5.4/manual.html#pdf-string.match)
--- @param range string
--- @param max_lines integer
--- @return integer
--- @return integer
local function parse_range(range, max_lines)
    -- ! Matching an optional capture group is not possible in lua
    -- ! `(x)?` will always fail so we need to parse the two cases separately

    --- @type string|nil, string|nil
    local min, max = range:match("^(%d+),(%d+)$")
    local min_range = tonumber(min)
    local max_range = tonumber(max)
    if min_range and max_range then return min_range, max_range end

    --- @type string|nil
    local single = range:match("^(%d+)$")
    local single_range = tonumber(single)
    if single_range then return single_range, single_range end

    return 1, max_lines
end

--- Apply substitution to lines
--- Returns new lines and a list of changed line indexes.
--- @param lines string[]
--- @param spec ReplaceSpec
--- @return string[] new_lines
--- @return integer[] changed_lines
local function apply_spec_to_lines(lines, spec)
    local transform = transform_line(spec)
    local new_lines, changed_lines = {}, {}

    local start_line, end_line = parse_range(spec.range, #lines)

    for i, line in ipairs(lines) do
        if i >= start_line and i <= end_line then
            if spec.is_replace then
                local new_line = transform(line)
                    -- TODO: Eventually this will need to be handled properly to actually split matches in to new lines
                    :gsub("\n", "\\n")
                    :gsub("\r", "\\r")
                new_lines[i] = new_line
                if new_line ~= line then
                    table.insert(changed_lines, i)
                end
            else
                local ok, pattern = pcall(vim.regex, spec.search)
                if ok and pattern:match_str(line) then
                    table.insert(changed_lines, i)
                end
                new_lines[i] = line
            end
        else
            new_lines[i] = line
        end
    end

    return new_lines, changed_lines
end

-----------------------------------------------------------
-- Hunks
-----------------------------------------------------------

--- Build hunks from a set of interesting line numbers.
--- @param total_lines integer
--- @param matches integer[] -- line numbers (1-based) where a match/diff occurred
--- @return Hunk[]
local function build_hunks(total_lines, matches)
    --- @type Hunk[]
    local hunks = {}
    for _, lnum in ipairs(matches) do
        local start = math.max(1, lnum - user_config.context_size)
        local finish = math.min(total_lines, lnum + user_config.context_size)
        if #hunks > 0 and start <= hunks[#hunks].finish + 1 then
            hunks[#hunks].finish = math.max(hunks[#hunks].finish, finish)
        else
            table.insert(hunks, { start = start, finish = finish })
        end
    end
    return hunks
end

--- Compute hunks between original and transformed lines.
--- If `spec.is_replace` is false, only marks matches of `spec.search`.
--- @param lines string[]
--- @param spec ReplaceSpec
--- @return string[]
--- @return Hunk[]
local function collect_hunks(lines, spec)
    local new_lines, changed = apply_spec_to_lines(lines, spec)
    return new_lines, build_hunks(#lines, changed)
end

-----------------------------------------------------------
-- Highlighting
-----------------------------------------------------------

--- Highlight all matches of a pattern in a line.
--- @param bufnr integer
--- @param line string
--- @param line_num integer
--- @param pattern vim.regex
--- @param offset integer
--- @param hl_group string
local function highlight_matches(bufnr, line, line_num, pattern, offset, hl_group)
    local j = 0
    while j < #line do
        local start, finish = pattern:match_str(line:sub(j + 1))
        if not start then break end
        start, finish = start + j, finish + j

        vim.api.nvim_buf_set_extmark(bufnr, ns, line_num, start + offset, {
            hl_group = hl_group,
            end_col = finish + offset
        })

        j = math.max(finish, j + 1)
    end
end

-----------------------------------------------------------
-- Diff rendering
-----------------------------------------------------------

--- Render a diff or search preview.
--- @param bufnr integer
--- @param orig_lines string[]
--- @param new_lines string[]
--- @param hunks Hunk[]
--- @param spec ReplaceSpec
--- @param filetype string
local function render_diff_preview(bufnr, orig_lines, new_lines, hunks, spec, filetype)
    --- @type string[], table<integer, ReplaceDiffMeta>
    local out, meta = {}, {}

    --- @param prefix string
    --- @param text string
    --- @param kind DiffMetaKind
    local function add(prefix, text, kind)
        table.insert(out, prefix .. text)
        meta[#out] = { kind = kind, text = text, }
    end

    for _, hunk in ipairs(hunks) do
        local orig_count, new_count = 0, 0

        for lnum = hunk.start, hunk.finish do
            local old, new = orig_lines[lnum] or "", new_lines[lnum] or ""
            if spec.is_replace and old ~= new then
                -- TODO: Properly handle empty strings, how should they be handled if they are deleted or just left empty
                if old ~= "" then orig_count = orig_count + 1 end
                if new ~= "" then new_count = new_count + 1 end
            else
                orig_count = orig_count + 1
                new_count = new_count + 1
            end
        end

        table.insert(out, string.format("@@ -%d,%d +%d,%d @@",
            hunk.start, orig_count,
            hunk.start, new_count
        ))

        for lnum = hunk.start, hunk.finish do
            local old, new = orig_lines[lnum] or "", new_lines[lnum] or ""
            if spec.is_replace and old ~= new then
                -- TODO: Properly handle empty strings, how should they be handled if they are deleted or just left empty
                if old ~= "" then add("-", old, "del") end
                if new ~= "" then add("+", new, "add") end
            else
                add(" ", old, "same")
            end
        end
    end

    setup_buffer(bufnr, filetype, out)

    for i, m_data in pairs(meta) do
        local buf_row = i - 1
        local end_col = #m_data.text + 1
        if m_data.kind == "add" then
            local ok, pattern = pcall(vim.regex, spec.replace)
            if ok then
                highlight_matches(bufnr, m_data.text, buf_row, pattern, 1, "Added")
                vim.api.nvim_buf_set_extmark(bufnr, ns, buf_row, 0, { hl_group = "DiffAdd", end_col = end_col, })
            end
        elseif m_data.kind == "del" then
            local ok, pattern = pcall(vim.regex, spec.search)
            if ok then
                vim.api.nvim_buf_set_extmark(bufnr, ns, buf_row, 0, { hl_group = "DiffDelete", end_col = end_col, })
                highlight_matches(bufnr, m_data.text, buf_row, pattern, 1, "Removed")
            end
        elseif not spec.is_replace then
            local ok, pattern = pcall(vim.regex, spec.search)
            if ok and pattern:match_str(m_data.text) ~= nil then
                vim.api.nvim_buf_set_extmark(bufnr, ns, buf_row, 0, { hl_group = "Search", end_col = end_col, })
                highlight_matches(bufnr, m_data.text, buf_row, pattern, 1, "TelescopeMatching")
            end
        end
    end
end


-----------------------------------------------------------
-- Telescope integration
-----------------------------------------------------------

--- Create an entry maker and setter for the current prompt/replace spec.
--- The entry_maker returns nil for empty or duplicate filename entries.
--- @return fun(line: string): TelescopeReplaceEntry|nil entry_maker
--- @return fun(prompt: ReplaceSpec|string): nil set_prompt
local function create_file_entry_maker()
    local displayer = entry_display.create({ separator = " ", items = { { width = 2 }, { remaining = true } } })
    --- @type ReplaceSpec|string, table<string, boolean>
    local last_prompt, seen = nil, {}

    --- Set the current prompt and replace spec used by produced entries.
    --- @param p ReplaceSpec|string
    local function set_prompt(p)
        last_prompt, seen = p, {}
    end

    --- Produce a Telescope entry from a grep line.
    --- @param line string
    --- @return TelescopeReplaceEntry|nil
    local function entry_maker(line)
        if not line or line == "" then return nil end
        --- @type string, string, string, string
        local filename, lnum, col, text = line:match("^(.-):(%d+):(%d+):(.*)$")
        if not filename then
            --- @type string, string, string
            filename, lnum, text = line:match("^(.-):(%d+):(.*)$")
        end
        if not filename or seen[filename] then return nil end
        seen[filename] = true

        local abs, icon, hl = vim.fn.fnamemodify(filename, ":p"), get_icon_and_hl(filename)
        return {
            value = abs,
            ordinal = abs,
            display = function() return displayer({ { icon, hl }, abs }) end,
            path = abs,
            prompt = last_prompt,
            filename = filename,
            lnum = tonumber(lnum),
            col = col and tonumber(col),
            text = text,
        }
    end

    return entry_maker, set_prompt
end

--- @param self {state: {bufnr: integer}}
--- @param entry TelescopeReplaceEntry
local function grep_buffer_preview(self, entry)
    local path = from_entry.path(entry, true, false)
    if not path then return end

    local lines = read_file_lines(path)
    if not lines then return end

    local ft = vim.filetype.match({ filename = path }) or "text"
    local spec = entry.prompt

    local new_lines, hunks = collect_hunks(lines, spec)
    if #hunks > 0 then
        render_diff_preview(self.state.bufnr, lines, new_lines, hunks, spec, ft)
    end
end

--- Buffer previewer for live grep results with diff/replace rendering.
--- This is a `telescope.previewers` object.
local grep_buffer_previewer = previewers.new_buffer_previewer({
    dyn_title = function(_, entry)
        return Path:new(from_entry.path(entry, false, false)):normalize(vim.uv.cwd())
    end,
    get_buffer_by_name = function(_, entry)
        return from_entry.path(entry, false, false)
    end,
    define_preview = grep_buffer_preview,
})

--- Apply the replacement spec to the given entry's file.
--- @param entry TelescopeReplaceEntry
--- @return boolean ok True on success.
--- @return string|nil err Error message if not ok.
local function apply_replacement_to_file(entry)
    local path = from_entry.path(entry, true, false) or entry.path or entry.value
    local spec = entry.prompt
    if not path or not spec or not spec.is_replace then
        return false, "invalid or non-replace entry"
    end

    local lines = read_file_lines(path)
    if not lines then return false, "failed to read" end
    local new_lines, changed = apply_spec_to_lines(lines, spec)

    if vim.tbl_isempty(changed) then return false, "no changes" end
    return write_file_lines(path, new_lines), nil
end

-----------------------------------------------------------
-- Picker
-----------------------------------------------------------

--- Create a finder that runs live grep (or substitute-style search) depending on prompt.
--- @return table Finder
local function live_grep_files()
    local entry_maker, set_prompt = create_file_entry_maker()
    local command_generator =
    --- @param prompt string
        function(prompt)
            if not prompt or prompt == "" then return nil end
            local parsed = parse_prompt_regex(prompt)
            set_prompt(parsed)
            return vim.iter({ conf.vimgrep_arguments, "--", parsed.search }):flatten():totable()
        end
    return finders.new_job(command_generator, entry_maker, nil, vim.uv.cwd())
end

--- @param prompt_bufnr number
--- @return boolean
local function search_replace_mappings(prompt_bufnr)
    actions.select_default:replace(function()
        --- @type Picker
        local picker = action_state.get_current_picker(prompt_bufnr)
        --- @type table<integer, TelescopeReplaceEntry>
        local selections = picker:get_multi_selection()

        if vim.tbl_isempty(selections) then
            --- @type TelescopeReplaceEntry
            local entry = action_state.get_selected_entry()
            table.insert(selections, entry)
        end

        actions.close(prompt_bufnr)
        for _, entry in ipairs(selections) do
            if entry.prompt.is_replace then
                local ok, err = apply_replacement_to_file(entry)
                if ok then
                    vim.notify("Replacements applied to " .. (entry.path or entry.value))
                else
                    vim.notify("Replacement failed: " .. tostring(err), vim.log.levels.ERROR)
                end
            else
                vim.cmd("edit " .. vim.fn.fnameescape(from_entry.path(entry, true, false) or entry.value))
            end
        end
    end)
    return true
end

--- Open the Search (& Replace) picker.
--- @return nil
local function search_replace()
    pickers.new({}, {
        prompt_title = "Search (& Replace `:s/<search>/<replace>/<flags>`)",
        push_cursor_on_edit = true,
        finder = live_grep_files(),
        previewer = grep_buffer_previewer,
        sorter = sorters.highlighter_only({}),
        attach_mappings = search_replace_mappings,
    }):find()
end

-----------------------------------------------------------
-- Setup
-----------------------------------------------------------

--- Setup the SearchReplace command and merge user options.
--- @param opts SearchReplaceConfig|nil
function M.setup(opts)
    user_config = vim.tbl_deep_extend('force', user_config, opts or {})
    vim.api.nvim_create_user_command("SearchReplace", search_replace, { desc = "Search (and Replace)" })
end

return M
