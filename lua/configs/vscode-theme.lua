vim.o.background = 'dark'

require('vscode').setup({
    transparent = true,
    underline_links = true,
    terminal_colors = true,
    disable_nvimtree_bg = true,
})

vim.cmd.colorscheme "vscode"

vim.api.nvim_set_hl(0, "Cursor", { bg = "#FFFFFF", fg = "#000000" })

-----------------------------------------------------------
-- Trailing Whitespaces
-----------------------------------------------------------
require("plugins.vscode-theme.trailing_whitespaces")

-----------------------------------------------------------
-- Better Comments
-----------------------------------------------------------
vim.hl.priorities.semantic_tokens = 75
require("plugins.treesitter.patch_priorities").override({
    ["*"] = {
        comment = 98,
        ["comment.documentation"] = 98,
    }
})

require("plugins.vscode-theme.better_comments").setup({
    ["?"]    = { fg = "#00aaff" }, -- ?
    ["*"]    = { fg = "#66bb00" }, -- *
    ["!"]    = { fg = "#ff6600" }, -- !
    ["TODO"] = { fg = "#cccc00" }, -- TODO
})
