vim.o.background = 'dark'

require('vscode').setup({
    transparent = true,
    underline_links = true,
    terminal_colors = true,
    disable_nvimtree_bg = true,
})

vim.cmd.colorscheme "vscode"

-- https://www.manjotbal.ca/blog/neovim-whitespace.html
vim.api.nvim_set_hl(0, 'TrailingWhitespace', { bg = 'Red' })
vim.api.nvim_create_autocmd('BufEnter', {
    pattern = '*',
    command = [[
        syntax clear TrailingWhitespace |
        syntax match TrailingWhitespace "\_s\+$"
    ]]
})
