vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

require("nvim-tree").setup({
    update_focused_file = {
        enable = true
    },
    filters = {
        dotfiles = false,
        git_ignored = false,
    },
    git = {
        enable = true,
        ignore = false,
        show_on_dirs = true,
    },
    renderer = {
        highlight_git = true,
        icons = {
            show = {
                git = false,
            },
            glyphs = {
                git = {
                    ignored = "",
                },
            },
        },
    },
})

vim.api.nvim_set_hl(0, "NvimTreeGitIgnored", { fg = "#888888", bold = false, italic = true })
