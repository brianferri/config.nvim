local M = {}

local function get_recent_items()
    local devicons = require("nvim-web-devicons")
    local seen, items = {}, {}

    for _, path in ipairs(vim.v.oldfiles) do
        if vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1 then
            if not seen[path] then
                seen[path] = true

                local is_dir = vim.fn.isdirectory(path) == 1
                local icon, hl_group

                if is_dir then
                    icon, hl_group = devicons.get_icon("folder", "dir", { default = true })
                else
                    local filename = vim.fn.fnamemodify(path, ":t")
                    local ext = vim.fn.fnamemodify(filename, ":e")
                    icon, hl_group = devicons.get_icon(filename, ext, { default = true })
                end

                table.insert(items, {
                    path = path,
                    is_dir = is_dir,
                    icon = icon or "",
                    icon_hl = hl_group or "Directory",
                })
            end
        end
    end

    return items
end

function M.open_recent()
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local previewers = require("telescope.previewers")
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local conf = require("telescope.config").values
    local entry_display = require("telescope.pickers.entry_display")

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
            entry_maker = function(entry)
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
            end,
        }),
        previewer = previewers.cat.new(conf),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr)
            actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                local selection = action_state.get_selected_entry()
                if selection then
                    vim.cmd("wa")
                    if selection.is_dir then
                        vim.cmd("cd " .. vim.fn.fnameescape(selection.path))
                        vim.cmd("edit .")
                    else
                        vim.cmd("edit " .. vim.fn.fnameescape(selection.path))
                    end
                end
            end)
            return true
        end,
    }):find()
end

function M.setup()
    vim.api.nvim_create_user_command("OpenRecent", M.open_recent, {
        desc = "Open Recent File or Directory",
    })
end

return M

