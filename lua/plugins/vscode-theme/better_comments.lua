local M = {}

---@class CommentFlags
---@field nested boolean  # 'n'
---@field requires_blank boolean  # 'b'
---@field first_only boolean  # 'f'
---@field start boolean  # 's'
---@field middle boolean  # 'm'
---@field ending boolean  # 'e'
---@field left_align boolean  # 'l' or implied default
---@field right_align boolean  # 'r'
---@field omit_for_O boolean  # 'O'
---@field allow_x_end boolean  # 'x'
---@field offset integer  # +N or -N

---@class CommentOption
---@field raw_flags string # original raw {flags}
---@field flags CommentFlags # fully decoded flags
---@field leader string # literal prefix text {string}

--- @alias BetterCommentsConfig table<string, vim.api.keyset.highlight>

--- Holds the comment format options for the focused buffer
--- @type CommentOption[]
local buffer_format_comments = {}

--- @type BetterCommentsConfig
local user_config = {}

-----------------------------------------------------------
-- Utility
-----------------------------------------------------------

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

local function escape_pattern(str)
    return str:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

-----------------------------------------------------------
-- Highlighting
-----------------------------------------------------------

--- Extract comment information for a buffer according to `:h format-comments`
--- @param comments string The comment string from `vim.bo[#].comments`
--- @return CommentOption[]
---
--- @see NeoVimDocs [`:h format-comments`](https://neovim.io/doc/user/change.html#format-comments)
local function parse_format_comments(comments)
    --- @type CommentOption[]
    local parts = {}
    for entry in comments:gmatch("[^,]+") do
        --- @type string, string
        local flags, leader = entry:match("^(.-):(.*)$")
        if flags == nil then
            flags = ""
            leader = entry
        end
        --- @type CommentFlags
        local decoded = {
            nested         = flags:find("n") ~= nil,
            requires_blank = flags:find("b") ~= nil,
            first_only     = flags:find("f") ~= nil,
            start          = flags:find("s") ~= nil,
            middle         = flags:find("m") ~= nil,
            ending         = flags:find("e") ~= nil,
            left_align     = flags:find("l") ~= nil or (flags:find("[sme]") ~= nil and not flags:find("[rl]")),
            right_align    = flags:find("r") ~= nil,
            omit_for_O     = flags:find("O") ~= nil,
            allow_x_end    = flags:find("x") ~= nil,
            offset         = tonumber(flags:match("(%-?%d+)")) or 0,
        }

        table.insert(parts, {
            raw_flags = flags,
            flags     = decoded,
            leader    = leader,
        })
    end
    return parts
end

--- Constructs a pattern to extract padding and text from a comment
--- @param comment_option CommentOption
--- @param comment_string string
--- @return string
local function comment_pattern(comment_option, comment_string)
    local leader = escape_pattern(comment_option.leader)
    local comment = escape_pattern(comment_string)
    local space = comment_option.flags.requires_blank and "%s+" or "%s*"

    local pattern = space .. ")(" .. comment .. ".*"

    if not comment_option.flags.start then
        -- ? `m` and `e` can have spaces before the comment line
        leader = "%s*" .. leader
    end

    pattern = "(" .. (comment_option.flags.ending
        and pattern .. leader
        or leader .. pattern
    ) .. ")$"

    return pattern
end

local ns = vim.api.nvim_create_namespace("BetterComments")

--- @param bufnr integer
local function highlight_comments(bufnr)
    local lang = vim.treesitter.language.get_lang(vim.bo[bufnr].filetype)
    if not lang then return end

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
            for pattern, _ in pairs(user_config) do
                for _, comment_option in ipairs(buffer_format_comments) do
                    -- * This is a single iteration since we're already iterating over single lines
                    for padding, hl_comment_text in line:gmatch(comment_pattern(comment_option, pattern)) do
                        local start_col = (i > 0) and #padding or col
                        local end_col = start_col + ((i > 0) and #hl_comment_text or #line)
                        vim.api.nvim_buf_set_extmark(bufnr, ns, linenr + i, start_col, {
                            end_col = end_col,
                            hl_group = hl_group_name(pattern),
                            -- ! We don't want to override all treesitter highlighting (default 100) just the `@comment`
                            priority = 99,
                        })
                        goto continue
                    end
                end
            end
            ::continue::
            i = i + 1
        end
    end
end

-----------------------------------------------------------
-- Setup
-----------------------------------------------------------

--- @param bufnr integer
local function update_buffer_format_comments(bufnr)
    buffer_format_comments = parse_format_comments(vim.bo[bufnr].comments)
    highlight_comments(bufnr)
end

--- Setup Better Comments and merge user options.
--- @param opts BetterCommentsConfig|nil
function M.setup(opts)
    user_config = vim.tbl_deep_extend('force', user_config, opts or {})
    set_hl_groups(user_config)

    local group = vim.api.nvim_create_augroup("BetterComments", { clear = true })
    vim.api.nvim_create_autocmd({ "BufEnter" }, {
        group = group,
        callback = function(args) update_buffer_format_comments(args.buf) end,
    })
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
        group = group,
        callback = function(args) highlight_comments(args.buf) end,
    })
end

return M
