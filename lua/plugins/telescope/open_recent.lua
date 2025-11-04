local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local previewers = require("telescope.previewers")
local action_state = require("telescope.actions.state")
local preview_utils = require("telescope.previewers.utils")
local entry_display = require("telescope.pickers.entry_display")

local conf = require("telescope.config").values

local devicons = require("nvim-web-devicons")

local M = {}

--- Provides a Telescope picker for recently opened files and directories.
--- uses `vim.v.oldfiles`

--- @class RecentItem
--- @field path string Absolute file or directory path.
--- @field is_dir boolean Whether the path is a directory.
--- @field icon string Devicon associated with the path.
--- @field icon_hl string Highlight group for the icon.

--- @class TelescopeEntry
--- @field value string
--- @field ordinal string
--- @field display fun(): string
--- @field path string
--- @field is_dir boolean

--- @class OpenRecentConfig
--- @field directory_preview { list_command: string, arguments: string[] } Optional preview command configuration.

--- @type OpenRecentConfig
local user_config = {
    directory_preview = {
        list_command = "ls",
        arguments = {},
    },
}

-----------------------------------------------------------
-- Utility
-----------------------------------------------------------

--- Gets devicon and highlight group for a file or directory.
--- @param path string The file or directory path.
--- @return string icon
--- @return string hl_group
--- @return boolean is_dir
local function get_icon_and_hl(path)
    if vim.fn.isdirectory(path) == 1 then
        local icon, hl = devicons.get_icon("folder", "", { default = true })
        return icon or "", hl or "Directory", true
    end

    local filename = vim.fn.fnamemodify(path, ":t")
    local ext = vim.fn.fnamemodify(filename, ":e")
    local icon, hl = devicons.get_icon(filename, ext, { default = true })
    return icon or "", hl or "Normal", false
end

--- Formats a path into a RecentItem with icon and metadata.
--- @param path string Path to format.
--- @return RecentItem
local function format_item(path)
    local icon, hl_group, is_dir = get_icon_and_hl(path)
    return {
        path = path,
        is_dir = is_dir,
        icon = icon,
        icon_hl = hl_group,
    }
end

--- Checks if a given path is a readable file or a directory.
--- @param path string Path to check.
--- @return boolean #True if valid.
local function is_valid_path(path)
    return vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1
end

--- Gets a list of valid, unique recent file/directory items.
--- @return RecentItem[]
local function get_recent_items()
    local seen = {}
    return vim.tbl_map(
        function(path)
            seen[path] = true
            return format_item(path)
        end,
        vim.tbl_filter(
            function(path) return is_valid_path(path) and not seen[path] end,
            vim.v.oldfiles
        )
    )
end

--- Runs a shell command and places its output into a buffer.
--- @param cmd string[]
--- @param bufnr integer
local function run_command_to_buffer(cmd, bufnr)
    vim.system(cmd, { text = true, clear_env = true }, function(result)
        vim.schedule(function()
            local lines = vim.split(result.stdout, "\n", { trimempty = true })
            if #lines == 0 then lines = { "[Command returned empty output]" } end
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        end)
    end):wait()
end

-----------------------------------------------------------
-- Previewer
-----------------------------------------------------------

--- Places the output of the configured list command into the passed buffer.
--- @param path string
--- @param bufnr integer
local function preview_directory(path, bufnr)
    local cmd = { user_config.directory_preview.list_command }
    vim.list_extend(cmd, user_config.directory_preview.arguments or {})
    table.insert(cmd, path)
    run_command_to_buffer(cmd, bufnr)
end

--- A new previewer from the `telescope.previewers.utils` which uses treesitter (if available) to highlight the buffer contents
local ts_buffer_previewer = previewers.new_buffer_previewer({
    define_preview = function(self, entry)
        if entry.is_dir then
            preview_directory(entry.path, self.state.bufnr)
        else
            previewers.buffer_previewer_maker(entry.path, self.state.bufnr, {
                bufname = self.state.bufname,
                winid = self.state.preview_win,
            })

            local ft = vim.api.nvim_get_option_value("filetype", { scope = "local", buf = self.state.bufnr })
            preview_utils.ts_highlighter(self.state.bufnr, ft)
        end
    end,
})

--- Creates an entry maker function for Telescope.
--- @param displayer fun(segments: (table|string)[]): string
--- @return fun(item: RecentItem): TelescopeEntry
local function create_entry_maker(displayer)
    return function(entry)
        return {
            value = entry.path,
            ordinal = entry.path,
            display = function()
                return displayer({
                    { entry.icon, entry.icon_hl },
                    entry.path,
                })
            end,
            path = entry.path,
            is_dir = entry.is_dir,
        }
    end
end

-----------------------------------------------------------
-- Picker
-----------------------------------------------------------

--- Opens the selected file or directory from the picker.
--- @param selection TelescopeEntry|nil
local function open_path(selection)
    if not selection then return end
    if selection.is_dir then
        -- before opening a new project we save everything, just in case
        vim.cmd("wa")
        vim.cmd("cd " .. vim.fn.fnameescape(selection.path))
        vim.cmd("e .")
    else
        vim.cmd("e " .. vim.fn.fnameescape(selection.path))
    end
end

--- @param prompt_bufnr number
--- @return boolean
local function open_recent_mappings(prompt_bufnr)
    actions.select_default:replace(function()
        --- @type Picker
        local picker = action_state.get_current_picker(prompt_bufnr)
        local selections = picker:get_multi_selection()

        if vim.tbl_isempty(selections) then
            --- @type TelescopeReplaceEntry
            local entry = action_state.get_selected_entry()
            table.insert(selections, entry)
        end

        actions.close(prompt_bufnr)
        for _, entry in ipairs(selections) do
            open_path(entry)
        end
    end)
    return true
end

local function open_recent()
    local displayer = entry_display.create({
        separator = " ",
        items = {
            { width = 2 },
            { remaining = true },
        },
    })

    pickers.new({}, {
        prompt_title = "Open Recent File/Dir",
        finder = finders.new_table({
            results = get_recent_items(),
            entry_maker = create_entry_maker(displayer),
        }),
        previewer = ts_buffer_previewer,
        sorter = conf.generic_sorter({}),
        attach_mappings = open_recent_mappings,
    }):find()
end

-----------------------------------------------------------
-- Setup
-----------------------------------------------------------

--- Setup the `Open Recent` command
---@param opts OpenRecentConfig
function M.setup(opts)
    user_config = vim.tbl_deep_extend('force', user_config, opts)
    vim.api.nvim_create_user_command("OpenRecent", open_recent, {
        desc = "Open Recent File or Directory",
    })
end

return M
