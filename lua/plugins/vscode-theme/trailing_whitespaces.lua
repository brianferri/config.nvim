-- https://www.manjotbal.ca/blog/neovim-whitespace.html
vim.api.nvim_set_hl(0, 'TrailingWhitespace', { bg = 'Red' })
vim.api.nvim_create_autocmd({ 'BufEnter', 'TermOpen' }, {
    pattern = '*',
    callback = function(args)
        vim.cmd([[ syntax clear TrailingWhitespace ]])
        if vim.bo[args.buf].buftype ~= '' then return end
        vim.cmd([[ syntax match TrailingWhitespace "\_s\+$" ]])
    end,
})
vim.api.nvim_create_user_command("RemoveTrailing",
    [[ silent keeppatterns %s/\s\+$//e ]],
    { desc = "Remove Trailing Whitespaces" }
)
