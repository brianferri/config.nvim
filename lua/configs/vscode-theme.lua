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

vim.hl.priorities.semantic_tokens = 75

local ns = vim.api.nvim_create_namespace("BetterComments")

--- @alias BetterCommentsConfig table<string, vim.api.keyset.highlight>

--- @type BetterCommentsConfig
local comment_hls = {
    ["?"]    = { fg = "#00aaff" }, -- ?
    ["*"]    = { fg = "#66bb00" }, -- *
    ["!"]    = { fg = "#ff6600" }, -- !
    ["TODO"] = { fg = "#cccc00" }, -- TODO
}

--- Some characters are invalid for hl group names
--- `BetterComment_?` would error, so we generate a unique name for it instead
--- @param marker string
--- @return string
local function hl_group_name(marker)
    return "BetterComment" .. marker:gsub("%W", function(c)
        return string.byte(c)
    end)
end

--- @param hl_groups BetterCommentsConfig
local function set_hl_groups(hl_groups)
    for marker, hl in pairs(hl_groups) do
        vim.api.nvim_set_hl(0, hl_group_name(marker), hl)
    end
end

--- @param bufnr integer
local function highlight_comments(bufnr)
    local lang = vim.bo[bufnr].filetype
    local ok, comments = pcall(vim.treesitter.query.parse, lang, "(comment) @comment")
    if not ok then return end

    local parser = vim.treesitter.get_parser(bufnr, lang, {})
    if not parser then return end

    local root = parser:parse()[1]:root()
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

    for _, node in comments:iter_captures(root, bufnr, 0, -1) do
        local linenr, col = node:range()
        local text = vim.treesitter.get_node_text(node, bufnr)
        local i = 0
        -- ? We want to handle each line separately, allowing us to encode
        -- ? meaning, potentially, in different lines of a multiline comment
        for line in text:gmatch("[^\n]+") do
            if #line > 1024 then goto continue end
            for pattern, _ in pairs(comment_hls) do
                for padding, hl_comment_text in line:gmatch("(.*)(" .. pattern .. "[^\n]+)$") do
                    local start_col = (i > 0) and #padding or col
                    local end_col = start_col + ((i > 0) and #hl_comment_text or #line)
                    vim.api.nvim_buf_set_extmark(bufnr, ns, linenr + i, start_col, {
                        end_col = end_col,
                        hl_group = hl_group_name(pattern),
                        -- ! We don't want to override all treesitter highlighting (default 100) just the `@comment`
                        -- TODO: Lower the `@comment` priority to 98
                        priority = 99,
                    })
                    goto continue
                end
            end
            ::continue::
            i = i + 1
        end
    end
end

set_hl_groups(comment_hls)
local group = vim.api.nvim_create_augroup("BetterComments", { clear = true })
vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI" }, {
    group = group,
    callback = function(args) highlight_comments(args.buf) end,
})
