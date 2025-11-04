vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

require("nvim-tree").setup({
    disable_netrw = true,
    hijack_cursor = true,
    update_focused_file = {
        enable = true,
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
        root_folder_label = false,
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
