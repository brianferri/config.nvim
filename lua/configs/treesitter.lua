require("nvim-treesitter.configs").setup({
    ensure_installed = "all",
    ignore_install = { "ipkg" },
    modules = {},
    sync_install = false,
    auto_install = true,
    highlight = {
        enable = true,
        disable = function(lang, buf)
            local max_filesize = 100 * 1024 -- 100 KB
            local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
            if ok and stats and stats.size > max_filesize then return true end
        end,
        additional_vim_regex_highlighting = false,
    },
})

-- ! There is no TS parser available for `sh` file types
-- ! https://github.com/nvim-treesitter/nvim-treesitter/#adding-parsers
vim.treesitter.language.register("bash", "sh")
