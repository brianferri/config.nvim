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

--- @class MarkerPattern
--- @field pattern string
--- @field hl_group string

--- Each buffer's comment leaders crossed with the configured markers. Both
--- halves are fixed for the life of a buffer, and building them per line was
--- the bulk of the work done on every keystroke.
--- @type table<integer, MarkerPattern[]>
local buffer_patterns = {}

--- @type table<integer, uv.uv_timer_t>
local timers = {}

--- @type BetterCommentsConfig
local user_config = {}

local redraw_debounce_ms = 40

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

--- Rows currently on screen across every window showing the buffer.
--- Nil when the buffer is displayed nowhere, in which case there is nothing to
--- highlight until a `BufWinEnter` brings it back.
--- @param bufnr integer
--- @return integer|nil top
--- @return integer|nil bot
local function visible_range(bufnr)
    local top, bot = math.huge, -1
    for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
        local info = vim.fn.getwininfo(win)[1]
        if info then
            top = math.min(top, info.topline - 1)
            bot = math.max(bot, info.botline)
        end
    end
    if bot < 0 then return nil, nil end
    return math.max(0, top), bot
end

--- @param bufnr integer
local function highlight_comments(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then return end

    local patterns = buffer_patterns[bufnr]
    if not patterns or vim.tbl_isempty(patterns) then return end

    local top, bot = visible_range(bufnr)
    if not top or not bot then return end

    local lang = vim.treesitter.language.get_lang(vim.bo[bufnr].filetype)
    if not lang then return end

    local ok, comments = pcall(vim.treesitter.query.parse, lang, "(comment) @comment")
    if not ok then return end

    local parser = vim.treesitter.get_parser(bufnr, lang, {})
    if not parser then return end

    local trees = parser:parse({ top, bot })
    local first_tree = trees and trees[1]

    if not first_tree then
        vim.api.nvim_buf_clear_namespace(bufnr, ns, top, bot)
        return
    end

    local root = first_tree:root()
    vim.api.nvim_buf_clear_namespace(bufnr, ns, top, bot)

    for _, node in comments:iter_captures(root, bufnr, top, bot) do
        local linenr, col = node:range()
        local text = vim.treesitter.get_node_text(node, bufnr)
        local i = 0
        -- ? We want to handle each line separately, allowing us to encode
        -- ? meaning, potentially, in different lines of a multiline comment
        for line in text:gmatch("[^\n]+") do
            local row = linenr + i
            -- ! A comment straddling the top of the viewport reports rows above
            -- ! the cleared range; marking those would stack on every redraw
            if row >= top and row < bot then
                for _, marker in ipairs(patterns) do
                    -- * This is a single iteration since we're already iterating over single lines
                    for padding, hl_comment_text in line:gmatch(marker.pattern) do
                        local start_col = (i > 0) and #padding or col
                        local end_col = start_col + ((i > 0) and #hl_comment_text or #line)
                        vim.api.nvim_buf_set_extmark(bufnr, ns, row, start_col, {
                            end_col = end_col,
                            hl_group = marker.hl_group,
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

--- @param bufnr integer
local function release_timer(bufnr)
    local timer = timers[bufnr]
    if not timer then return end
    timer:stop()
    if not timer:is_closing() then timer:close() end
    timers[bufnr] = nil
end

--- @param bufnr integer
local function schedule_highlight(bufnr)
    release_timer(bufnr)

    local timer = vim.uv.new_timer()
    if not timer then return highlight_comments(bufnr) end

    timers[bufnr] = timer
    timer:start(redraw_debounce_ms, 0, vim.schedule_wrap(function()
        release_timer(bufnr)
        highlight_comments(bufnr)
    end))
end

-----------------------------------------------------------
-- Setup
-----------------------------------------------------------

--- @param bufnr integer
local function update_buffer_patterns(bufnr)
    local options = parse_format_comments(vim.bo[bufnr].comments)
    --- @type MarkerPattern[]
    local patterns = {}
    for marker in pairs(user_config) do
        local hl_group = hl_group_name(marker)
        for _, comment_option in ipairs(options) do
            table.insert(patterns, {
                pattern = comment_pattern(comment_option, marker),
                hl_group = hl_group,
            })
        end
    end
    buffer_patterns[bufnr] = patterns
    highlight_comments(bufnr)
end

--- Setup Better Comments and merge user options.
--- @param opts BetterCommentsConfig|nil
function M.setup(opts)
    user_config = vim.tbl_deep_extend('force', user_config, opts or {})
    set_hl_groups(user_config)

    local group = vim.api.nvim_create_augroup("BetterComments", { clear = true })
    vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "FileType" }, {
        group = group,
        callback = function(args) update_buffer_patterns(args.buf) end,
    })
    -- ! `TextChanged` fires for whichever buffer changed, not the focused one,
    -- ! so the leaders have to be looked up per buffer
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
        group = group,
        callback = function(args) schedule_highlight(args.buf) end,
    })
    -- ? Only the viewport is marked, so scrolling has to bring the rest in
    vim.api.nvim_create_autocmd({ "WinScrolled", "WinResized" }, {
        group = group,
        callback = function()
            for _, winid in ipairs(vim.api.nvim_list_wins()) do
                schedule_highlight(vim.api.nvim_win_get_buf(winid))
            end
        end,
    })
    vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
        group = group,
        callback = function(args)
            release_timer(args.buf)
            buffer_patterns[args.buf] = nil
        end,
    })
end

-- ? Reachable for `tests/`: `:h format-comments` is dense enough that the
-- ? decoding is worth pinning
M._parse_format_comments = parse_format_comments
M._comment_pattern = comment_pattern

return M
