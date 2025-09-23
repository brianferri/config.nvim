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

local M = {}

--- @class SearchReplaceConfig
--- @field context_size integer? Number of context lines around matches.

--- @class ReplaceSpec
--- @field is_replace boolean
--- @field search string
--- @field replace string
--- @field flags string

--- @class Hunk
--- @field start integer
--- @field finish integer

--- @class DiffLineMeta
--- @field lnum integer
--- @field matched boolean

--- @class ReplaceDiffMeta
--- @field kind "add"|"del"|"same"
--- @field text string

--- @class TelescopeReplaceEntry: table
--- @field value string
--- @field ordinal string
--- @field display fun(): string
--- @field path string
--- @field prompt string|nil
--- @field replace_spec ReplaceSpec|nil
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

--- Build substitute flags string.
--- @param flags string|nil
--- @return string
local function build_substitute_flags(flags)
    local result = ""
    if flags and flags:find("g") then result = result .. "g" end
    if flags and flags:find("i") then result = result .. "i" end
    return result
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

--- Parse a substitute-style prompt (e.g. `:s/foo/bar/g`).
--- @param prompt string|nil
--- @return ReplaceSpec|nil
local function parse_prompt_regex(prompt)
    if not prompt or prompt == "" then return nil end
    if not vim.startswith(prompt, ":s") then return nil end

    local sep = prompt:sub(3, 3)
    if not sep or sep == "" then return nil end

    --- @param start_index integer
    --- @return integer|nil
    local function next_unescaped(start_index)
        local idx = start_index
        while idx <= #prompt do
            local ch = prompt:sub(idx, idx)
            if ch == "\\" then
                idx = idx + 2
            elseif ch == sep then
                return idx
            else
                idx = idx + 1
            end
        end
        return nil
    end

    local search_start = 4
    local search_end = next_unescaped(search_start)
    if not search_end then return nil end
    local search = prompt:sub(search_start, search_end - 1)

    local replace_start = search_end + 1
    local replace_end = next_unescaped(replace_start)
    if not replace_end then return nil end
    local replace = prompt:sub(replace_start, replace_end - 1)

    local flags = prompt:sub(replace_end + 1)
    return { is_replace = true, search = search, replace = replace, flags = flags or "" }
end

-----------------------------------------------------------
-- Hunks
-----------------------------------------------------------

--- Collect hunks where a pattern matches.
--- @param lines string[]
--- @param prompt string
--- @return Hunk[]
local function collect_hunks(lines, prompt)
    --- @type Hunk[], vim.regex
    local hunks, pattern = {}, vim.regex(vim.pesc(prompt))
    for lnum, line in ipairs(lines) do
        if pattern:match_str(line) then
            local start = math.max(1, lnum - user_config.context_size)
            local finish = math.min(#lines, lnum + user_config.context_size)
            if #hunks > 0 and start <= hunks[#hunks].finish + 1 then
                hunks[#hunks].finish = math.max(hunks[#hunks].finish, finish)
            else
                table.insert(hunks, { start = start, finish = finish })
            end
        end
    end
    return hunks
end

--- Collect hunks where lines differ between old and new versions.
--- @param orig_lines string[]
--- @param new_lines string[]
--- @return Hunk[]
local function collect_changed_hunks(orig_lines, new_lines)
    --- @type Hunk[]
    local hunks = {}
    for lnum = 1, math.max(#orig_lines, #new_lines) do
        local orig, new = orig_lines[lnum] or "", new_lines[lnum] or ""
        if orig ~= new then
            local start = math.max(1, lnum - user_config.context_size)
            local finish = math.min(#orig_lines, lnum + user_config.context_size)
            if #hunks > 0 and start <= hunks[#hunks].finish + 1 then
                hunks[#hunks].finish = math.max(hunks[#hunks].finish, finish)
            else
                table.insert(hunks, { start = start, finish = finish })
            end
        end
    end
    return hunks
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
local function highlight_matches(bufnr, line, line_num, pattern, offset)
    local j = 0
    while j < #line do
        local start, finish = pattern:match_str(line:sub(j + 1))
        if not start then break end
        start, finish = start + j, finish + j
        vim.api.nvim_buf_add_highlight(bufnr, -1, "TelescopeMatching", line_num, start + offset, finish + offset)
        j = finish
    end
end

-----------------------------------------------------------
-- Diff rendering
-----------------------------------------------------------

--- Render a diff with highlights for matches.
--- @param bufnr integer
--- @param lines string[]
--- @param hunks Hunk[]
--- @param prompt string
--- @param filetype string
local function render_diff(bufnr, lines, hunks, prompt, filetype)
    --- @type string[], table<integer, DiffLineMeta>
    local out, line_map = {}, {}
    local pattern = vim.regex(vim.pesc(prompt))

    for _, hunk in ipairs(hunks) do
        table.insert(out, string.format("@@@ -%d,%d +%d,%d @@@",
            hunk.start, hunk.finish - hunk.start + 1, hunk.start, hunk.finish - hunk.start + 1))
        for line = hunk.start, hunk.finish do
            local text = lines[line]
            local matched = pattern:match_str(text) ~= nil
            table.insert(out, (matched and "+" or " ") .. text)
            line_map[#out] = { lnum = line, matched = matched }
        end
    end

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, out)
    vim.api.nvim_set_option_value("filetype", filetype, { buf = bufnr })
    preview_utils.ts_highlighter(bufnr, filetype)

    for i, meta in pairs(line_map) do
        if meta.matched then
            vim.api.nvim_buf_add_highlight(bufnr, -1, "DiffAdd", i - 1, 0, -1)
            highlight_matches(bufnr, lines[meta.lnum], i - 1, pattern, 1)
        end
    end
end

--- Render a replacement diff with add/delete/same markings and highlights.
--- @param bufnr integer
--- @param orig_lines string[]
--- @param new_lines string[]
--- @param hunks Hunk[]
--- @param replace_spec ReplaceSpec
--- @param filetype string
local function render_replace_diff(bufnr, orig_lines, new_lines, hunks, replace_spec, filetype)
    --- @type string[], table<integer, ReplaceDiffMeta>
    local out, line_map = {}, {}
    for _, hunk in ipairs(hunks) do
        table.insert(out, string.format("@@@ -%d,%d +%d,%d @@@",
            hunk.start, hunk.finish - hunk.start + 1, hunk.start, hunk.finish - hunk.start + 1))
        for line = hunk.start, hunk.finish do
            local old_text, new_text = orig_lines[line] or "", new_lines[line] or ""
            if old_text ~= new_text then
                table.insert(out, "-" .. old_text)
                line_map[#out] = { kind = "del", text = old_text }
                table.insert(out, "+" .. new_text)
                line_map[#out] = { kind = "add", text = new_text }
            else
                table.insert(out, " " .. old_text)
                line_map[#out] = { kind = "same", text = old_text }
            end
        end
    end

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, out)
    vim.api.nvim_set_option_value("filetype", filetype, { buf = bufnr })
    preview_utils.ts_highlighter(bufnr, filetype)

    local pattern_ok, pattern = pcall(vim.regex, replace_spec.search)
    for i, meta in pairs(line_map) do
        if meta.kind == "add" then
            vim.api.nvim_buf_add_highlight(bufnr, -1, "DiffAdd", i - 1, 0, -1)
            if pattern_ok then
                highlight_matches(bufnr, meta.text, i - 1, pattern, 1)
            end
        elseif meta.kind == "del" then
            vim.api.nvim_buf_add_highlight(bufnr, -1, "DiffDelete", i - 1, 0, -1)
        end
    end
end

-----------------------------------------------------------
-- Telescope integration
-----------------------------------------------------------

--- Create an entry maker and setter for the current prompt/replace spec.
--- The entry_maker returns nil for empty or duplicate filename entries.
--- @return fun(line: string): TelescopeReplaceEntry|nil entry_maker
--- @return fun(p: string|nil, replace_spec: ReplaceSpec|nil): nil set_prompt
local function create_file_entry_maker()
    local displayer = entry_display.create({ separator = " ", items = { { width = 2 }, { remaining = true } } })
    --- @type string?, ReplaceSpec?, table<string, boolean>
    local last_prompt, last_replace_spec, seen = nil, nil, {}

    --- Set the current prompt and replace spec used by produced entries.
    --- @param p string|nil
    --- @param replace_spec ReplaceSpec|nil
    local function set_prompt(p, replace_spec)
        last_prompt, last_replace_spec, seen = p, replace_spec, {}
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
            replace_spec = last_replace_spec,
            filename = filename,
            lnum = tonumber(lnum),
            col = col and tonumber(col),
            text = text,
        }
    end

    return entry_maker, set_prompt
end

--- Buffer previewer for live grep results with diff/replace rendering.
--- This is a `telescope.previewers` object.
local grep_buffer_previewer = (function()
    local cwd = vim.loop.cwd()
    return previewers.new_buffer_previewer({
        dyn_title = function(_, entry) return Path:new(from_entry.path(entry, false, false)):normalize(cwd) end,
        get_buffer_by_name = function(_, entry) return from_entry.path(entry, false, false) end,
        define_preview =
        --- @param self {state: {bufnr: integer}}
        --- @param entry TelescopeReplaceEntry
            function(self, entry)
                local path = from_entry.path(entry, true, false)
                if not path then return end

                local lines = read_file_lines(path)
                if not lines then return end

                local ft = vim.filetype.match({ filename = path }) or "text"
                if entry.replace_spec and entry.replace_spec.is_replace then
                    local spec = entry.replace_spec
                    -- This check is only for the type checker
                    if spec == nil then return end

                    --- @type string[]
                    local new_lines = {}
                    local sub_flags = build_substitute_flags(spec.flags)
                    for _, line in ipairs(lines) do
                        table.insert(new_lines, vim.fn.substitute(line, spec.search, spec.replace, sub_flags))
                    end
                    local hunks = collect_changed_hunks(lines, new_lines)
                    if #hunks > 0 then
                        render_replace_diff(self.state.bufnr, lines, new_lines, hunks, spec, ft)
                    else
                        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
                    end
                else
                    local hunks = collect_hunks(lines, entry.prompt)
                    if #hunks > 0 then
                        render_diff(self.state.bufnr, lines, hunks, entry.prompt, ft)
                    else
                        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
                    end
                end
            end,
    })
end)()

--- Create a finder that runs live grep (or substitute-style search) depending on prompt.
--- @return table Finder
local function live_grep_files()
    local entry_maker, set_prompt = create_file_entry_maker()
    local command_generator =
    --- @param prompt string
        function(prompt)
            if not prompt or prompt == "" then return nil end
            local parsed = parse_prompt_regex(prompt)
            if parsed and parsed.is_replace then
                set_prompt(parsed.search, parsed)
                return vim.tbl_flatten({ conf.vimgrep_arguments, "--", parsed.search })
            else
                set_prompt(prompt, nil)
                return vim.tbl_flatten({ conf.vimgrep_arguments, "--", prompt })
            end
        end
    return finders.new_job(command_generator, entry_maker, nil, vim.loop.cwd())
end

--- Apply the replacement spec to the given entry's file.
--- @param entry TelescopeReplaceEntry
--- @return boolean ok True on success.
--- @return string|nil err Error message if not ok.
local function apply_replacement_to_file(entry)
    local path, spec = from_entry.path(entry, true, false) or entry.path or entry.value, entry.replace_spec
    if not path or not spec then return false, "invalid entry" end

    local file_lines = read_file_lines(path)
    if not file_lines then return false, "failed to read file" end

    local sub_flags, new_lines, changed = build_substitute_flags(spec.flags), {}, false
    for _, line in ipairs(file_lines) do
        local new_line = vim.fn.substitute(line, spec.search, spec.replace, sub_flags)
        if new_line ~= line then changed = true end
        table.insert(new_lines, new_line)
    end
    if not changed then return false, "no changes" end
    local wrote = write_file_lines(path, new_lines)
    if wrote then
        return true, nil
    else
        return false, "failed to write"
    end
end

-----------------------------------------------------------
-- Picker
-----------------------------------------------------------

--- Open the Search (& Replace) picker.
--- @return nil
local function search_replace()
    pickers.new({}, {
        prompt_title = "Search (& Replace)",
        push_cursor_on_edit = true,
        finder = live_grep_files(),
        previewer = grep_buffer_previewer,
        sorter = sorters.highlighter_only({}),
        attach_mappings =
        --- @param prompt_bufnr number
        --- @return boolean
        function(prompt_bufnr)
            actions.select_default:replace(function()
                --- @type TelescopeReplaceEntry
                local entry = action_state.get_selected_entry()
                if not entry then return actions.close(prompt_bufnr) end
                actions.close(prompt_bufnr)
                if entry.replace_spec and entry.replace_spec.is_replace then
                    local ok, err = apply_replacement_to_file(entry)
                    if ok then
                        vim.notify("Replacements applied to " .. (entry.path or entry.value))
                    else
                        vim.notify("Replacement failed: " .. tostring(err), vim.log.levels.ERROR)
                    end
                else
                    vim.cmd("edit " .. vim.fn.fnameescape(from_entry.path(entry, true, false) or entry.value))
                end
            end)
            return true
        end,
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
