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

local ns = vim.api.nvim_create_namespace("BetterComments")

--- @type table<string, vim.api.keyset.highlight>
local comment_hls = {
    ["?"]    = { fg = "#00aaff" }, -- ?
    ["*"]    = { fg = "#66bb00" }, -- *
    ["!"]    = { fg = "#ff6600" }, -- !
    ["TODO"] = { fg = "#cccc00" }, -- TODO
}

--- Global options to apply to the highlight groups
--- @type vim.api.keyset.highlight
local hl_opts = {}

--- Some characters are invalid for hl group names
--- `BetterComment_?` would error, so we generate a unique name for it instead
--- @param marker string
--- @return string
local function hl_group_name(marker)
    return "BetterComment_" .. marker:gsub("%W", function(c)
        return string.byte(c)
    end)
end

for marker, hl in pairs(comment_hls) do
    vim.api.nvim_set_hl(
        0, hl_group_name(marker),
        vim.tbl_extend('keep', hl, hl_opts)
    )
end

--- @param bufnr integer
local function highlight_comments(bufnr)
    local lang = vim.api.nvim_buf_get_option(bufnr, "filetype")
    local ok, query = pcall(vim.treesitter.query.parse, lang, "(comment) @c")
    if not ok then return end

    local parser = vim.treesitter.get_parser(bufnr, lang, {})
    if not parser then return end

    local root = parser:parse()[1]:root()
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

    for _, node in query:iter_captures(root, bufnr, 0, -1) do
        local text = vim.treesitter.get_node_text(node, bufnr)
        local i = 0
        for line in text:gmatch("[^\n]+") do
            if #line > 1024 then goto continue end
            for pat, _ in pairs(comment_hls) do
                if line:match(pat) then
                    local linenr, col = node:range()
                    vim.api.nvim_buf_add_highlight(bufnr, ns, hl_group_name(pat), linenr + i, col, -1)
                    break
                end
            end
            ::continue::
            i = i + 1
        end
    end
end

local group = vim.api.nvim_create_augroup("BetterComments", { clear = true })
vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI" }, {
    group = group,
    callback = function(args) highlight_comments(args.buf) end,
})
