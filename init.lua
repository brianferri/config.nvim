-- Bootstrap lazy.nvim if not installed
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end

-- vim specific
vim.opt.rtp:prepend(lazypath)
vim.diagnostic.config({
    virtual_text = true,
    update_in_insert = true,
    float = {
        border = "rounded",
        source = "if_many"
    }
})

vim.opt.mousemoveevent = true
vim.opt.termguicolors = true
vim.opt.number = true
vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4

vim.opt.list = true
vim.opt.listchars = { space = "·", tab = "› ", trail = "_" }

-- Load plugins
require("lazy").setup({
    { import = "plugins" }
})

require("configs.keybinds")
