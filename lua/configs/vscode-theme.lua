vim.o.background = 'dark'

require('vscode').setup({
    transparent = true,
    underline_links = true,
    terminal_colors = true,
    disable_nvimtree_bg = true,
})

vim.cmd.colorscheme "vscode"

-----------------------------------------------------------
-- Trailing Whitespaces
-----------------------------------------------------------

-- https://www.manjotbal.ca/blog/neovim-whitespace.html
vim.api.nvim_set_hl(0, 'TrailingWhitespace', { bg = 'Red' })
vim.api.nvim_create_autocmd('BufEnter', {
    pattern = '*',
    command = [[
        syntax clear TrailingWhitespace |
        syntax match TrailingWhitespace "\_s\+$"
    ]]
})

-----------------------------------------------------------
-- Better Comments
-----------------------------------------------------------

--- @type table<string, vim.api.keyset.highlight>
local comment_hls = {
    ["?"]    = { fg = "#00aaff" }, -- ?
    ["*"]    = { fg = "#66bb00" }, -- *
    ["!"]    = { fg = "#ff6600" }, -- !
    ["TODO"] = { fg = "#cccc00" }, -- TODO
}

--- @param marker string
--- @return string
local function hl_group_name(marker)
    return "BetterComment_" .. marker:gsub("%W", function(c)
        return string.byte(c)
    end)
end

for marker, hl in pairs(comment_hls) do
    vim.api.nvim_set_hl(0, hl_group_name(marker), hl)
end

--- @param bufnr integer
local function highlight_comments(bufnr)
    local lang = vim.api.nvim_buf_get_option(bufnr, "filetype")
    local ok, query = pcall(vim.treesitter.query.parse, lang, "(comment) @c")
    if not ok then return end

    local parser = vim.treesitter.get_parser(bufnr, lang, {})
    if not parser then return end

    local root = parser:parse()[1]:root()
    for _, node in query:iter_captures(root, bufnr, 0, -1) do
        local text = vim.treesitter.get_node_text(node, bufnr)
        local line, col = node:range()

        for pat, _ in pairs(comment_hls) do
            if text:match(pat) then
                vim.api.nvim_buf_add_highlight(bufnr, -1, hl_group_name(pat), line, col, -1)
                break
            end
        end
    end
end

local group = vim.api.nvim_create_augroup("BetterComments", { clear = true })
vim.api.nvim_create_autocmd({ "BufEnter" }, {
    group = group,
    callback = function(args) highlight_comments(args.buf) end,
})
