vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

require("nvim-tree").setup({
    disable_netrw = true,
    hijack_cursor = true,
    create_in_closed_folder = true,
    focus_empty_on_setup = true,
    sync_root_with_cwd = true,
    update_focused_file = {
        enable = true,
        update_root = true,
    },
    filters = {
        dotfiles = false,
        git_ignored = false,
    },
    git = {
        enable = true,
    },
    modified = {
        enable = true,
    },
    renderer = {
        indent_markers = {
            enable = true,
        },
        highlight_git = true,
        highlight_modified = "icon",
        icons = {
            glyphs = {
                git = {
                    ignored = "",
                    unstaged = "M",
                    renamed = "R",
                    untracked = "U",
                    deleted = "D"
                },
            },
        },
    },
})

vim.api.nvim_set_hl(0, "NvimTreeGitIgnored", { fg = "#888888", bold = false, italic = true })
