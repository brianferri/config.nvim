-- https://www.manjotbal.ca/blog/neovim-whitespace.html
vim.api.nvim_set_hl(0, 'TrailingWhitespace', { bg = 'Red' })
vim.api.nvim_create_autocmd('BufEnter', {
    pattern = '*',
    command = [[
        syntax clear TrailingWhitespace |
        syntax match TrailingWhitespace "\_s\+$"
    ]]
})
vim.api.nvim_create_user_command("RemoveTrailing",
    [[%s/\_s\+$//e]],
    { desc = "Remove Trailing Whitespaces" }
)
