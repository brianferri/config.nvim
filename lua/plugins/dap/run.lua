local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local entry_display = require("telescope.pickers.entry_display")
local previewers = require("telescope.previewers")
local preview_utils = require("telescope.previewers.utils")
local conf = require("telescope.config").values

local dap = require("dap")
local Path = require("plenary.path")
local scan = require("plenary.scandir")

local M = {}

--- @class DapAdapterDefinition
--- @field name string Name of the registered adapter (e.g. "lldb")
--- @field request string (e.g. "launch" or "attach")
--- @field config table Additional launch config fields (like args, stopOnEntry, etc.)
--- @field adapter dap.Adapter
---
--- @class DapRunConfig
--- @field search_root string? Directory to search executables from.
--- @field adapter_options table<string, DapAdapterDefinition>

--- @type DapRunConfig
local user_config = {
    search_root = ".",
    adapter_options = {},
}

--- Apply user configuration and register DAP adapters
--- @param opts DapRunConfig
function M.configure(opts)
    user_config.search_root = opts.search_root or user_config.search_root
    user_config.adapter_options = vim.tbl_extend(
        "force",
        user_config.adapter_options,
        opts.adapter_options
    )
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

--- Pick a DAP adapter
--- @param callback fun(cfg: DapAdapterDefinition)
local function pick_adapter(callback)
    local opts = user_config.adapter_options
    local keys = vim.tbl_keys(opts)
    if #keys == 0 then
        vim.notify("No DAP adapter options configured.", vim.log.levels.WARN)
        return
    end
    if #keys == 1 then
        callback(opts[keys[1]])
        return
    end
    vim.ui.select(keys, { prompt = "Select DAP Adapter:" }, function(choice)
        if choice then callback(opts[choice]) end
    end)
end

--- Run nvim-dap with selected adapter and executable
--- @param path string
--- @param cfg DapAdapterDefinition
local function run_dap(path, cfg)
    dap.run(
        vim.tbl_deep_extend("force", cfg.config, {
            program = path,
            cwd = Path:new(path):parent():absolute(),
        })
    )
end

--- Creates entry maker for executable files
--- @param displayer fun(segments: (table|string)[]): string
--- @return fun(path: string): table
local function create_entry_maker(displayer)
    local devicons = require("nvim-web-devicons")
    return function(path)
        local filename = Path:new(path):make_relative()
        local icon, hl = devicons.get_icon(filename, nil, { default = true })
        return {
            value = path,
            ordinal = filename,
            display = function()
                return displayer({ { icon, hl }, filename })
            end,
            path = path,
        }
    end
end

--- Previewer: show file info in a buffer
local previewer = previewers.new_buffer_previewer({
    define_preview = function(self, entry)
        local stat = vim.loop.fs_stat(entry.path)
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {
            "Path: " .. entry.path,
            "Size: " .. (stat and stat.size or "unknown") .. " bytes",
            "Modified: " .. (stat and os.date("%c", stat.mtime.sec) or "unknown"),
        })
        preview_utils.highlighter(self.state.bufnr, "markdown")
    end,
})

--- Launch telescope picker to select executable
function M.dap_run()
    local executables = find_executables()
    if vim.tbl_isempty(executables) then
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
            results = executables,
            entry_maker = create_entry_maker(displayer),
        }),
        previewer = previewer,
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr)
            actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                local selection = action_state.get_selected_entry()
                if selection then
                    pick_adapter(function(adapter_cfg)
                        run_dap(selection.path, adapter_cfg)
                    end)
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
