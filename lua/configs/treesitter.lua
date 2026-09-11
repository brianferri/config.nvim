require("nvim-treesitter").install({
    "bash", "c", "cmake", "cpp", "css", "diff", "dockerfile",
    "git_config", "git_rebase", "gitcommit", "gitignore", "go", "gomod",
    "graphql", "html", "javascript", "jsdoc", "json", "lua", "luadoc",
    "make", "markdown", "markdown_inline", "php", "python", "query", "regex",
    "ruby", "rust", "scss", "sql", "toml", "tsx", "typescript", "vim",
    "vimdoc", "vue", "xml", "yaml", "zig",
})

vim.api.nvim_create_autocmd('FileType', {
    callback = function() pcall(vim.treesitter.start) end,
})

-- ! There is no TS parser available for `sh` file types
-- ! https://github.com/nvim-treesitter/nvim-treesitter/issues/767
-- ! https://github.com/nvim-treesitter/nvim-treesitter/#adding-parsers
vim.treesitter.language.register("bash", { "sh" })
