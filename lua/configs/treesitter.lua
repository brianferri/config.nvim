require("nvim-treesitter").install({ "all" })

vim.api.nvim_create_autocmd('FileType', {
    callback = function() pcall(vim.treesitter.start) end,
})

-- ! There is no TS parser available for `sh` file types
-- ! https://github.com/nvim-treesitter/nvim-treesitter/issues/767
-- ! https://github.com/nvim-treesitter/nvim-treesitter/#adding-parsers
vim.treesitter.language.register("bash", { "sh" })
