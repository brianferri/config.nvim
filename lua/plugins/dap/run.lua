local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local entry_display = require("telescope.pickers.entry_display")
local previewers = require("telescope.previewers")
local preview_utils = require("telescope.previewers.utils")
local conf = require("telescope.config").values

local Path = require("plenary.path")
local scan = require("plenary.scandir")

local M = {}

--- @class DapRunConfig
--- @field search_root string? Directory to search executables from.

--- @type DapRunConfig
local user_config = {
    search_root = ".",
}

--- Apply user configuration
--- @param opts DapRunConfig
function M.configure(opts)
    opts = opts or {}
    if opts.search_root and opts.search_root ~= "" then
        user_config.search_root = opts.search_root
    end
end

--- Scan for executable files under search_root
--- @return string[]
local function find_executables()
    local results = {}
    scan.scan_dir(user_config.search_root, {
        hidden = false,
        add_dirs = false,
        depth = 5,
        on_insert = function(path)
            if vim.fn.executable(path) == 1 then
                table.insert(results, path)
            end
        end,
    })
    return results
end

--- Start dap session with selected binary
--- @param path string
local function run_dap(path)
    local dap = require("dap")
    local cwd = Path:new(path):parent():absolute()
    dap.run({
        name = "Run Executable",
        type = "lldb",
        request = "launch",
        program = path,
        cwd = cwd,
    })
end

--- Creates entry maker for executable files
--- @param displayer fun(segments: (table|string)[]): string
--- @return fun(path: string): table
local function create_entry_maker(displayer)
    local devicons = require("nvim-web-devicons")
    return function(path)
        local filename = Path:new(path):make_relative()
        local icon, icon_hl = devicons.get_icon(filename, nil, { default = true })
        return {
            value = path,
            ordinal = filename,
            display = function()
                return displayer({
                    { icon, icon_hl },
                    filename,
                })
            end,
            path = path,
        }
    end
end

--- Previewer: show file info in a buffer
local previewer = previewers.new_buffer_previewer({
    define_preview = function(self, entry)
        local path = entry.path
        local stat = vim.loop.fs_stat(path)
        local lines = {
            "Path: " .. path,
            "Size: " .. (stat and stat.size or "unknown") .. " bytes",
            "Modified: " .. (stat and os.date("%c", stat.mtime.sec) or "unknown"),
        }
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
        preview_utils.highlighter(self.state.bufnr, "markdown")
    end,
})

--- Launch telescope picker to select executable
function M.dap_run()
    local results = find_executables()
    if vim.tbl_isempty(results) then
        vim.notify("No executables found under: " .. user_config.search_root, vim.log.levels.WARN)
        return
    end

    local displayer = entry_display.create({
        separator = " ",
        items = {
            { width = 2 },
            { remaining = true },
        },
    })

    pickers.new({}, {
        prompt_title = "Run Executable (DAP)",
        finder = finders.new_table({
            results = results,
            entry_maker = create_entry_maker(displayer),
        }),
        previewer = previewer,
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr)
            actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                local selection = action_state.get_selected_entry()
                if selection then
                    run_dap(selection.path)
                end
            end)
            return true
        end,
    }):find()
end

--- Setup DapRun command
--- @param opts DapRunConfig
function M.setup(opts)
    M.configure(opts)
    vim.api.nvim_create_user_command("DapRun", M.dap_run, {
        desc = "Pick executable to run with nvim-dap",
    })
end

return M
