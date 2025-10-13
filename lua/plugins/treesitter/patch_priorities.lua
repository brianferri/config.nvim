local M = {}

--- @alias UserPriorities table<string, table<string, integer>>

--- @type UserPriorities
local user_priorities = {}

--- Monkey patch treesitter capture iteration to inject priority metadata.
--- @see https://github.com/nvim-treesitter/nvim-treesitter/discussions/7816
--- @see https://github.com/memchr/nvim/commit/e143f6101aac24d008481c264f7ad850d753c223
--- @param Query vim.treesitter.Query
local function patch_query(Query)
    local original_iter = Query.iter_captures

    function Query:iter_captures(node, source, start, stop, opts)
        local iter = original_iter(self, node, source, start, stop, opts)

        -- Determine if we have any priorities to apply
        local lang_priorities = user_priorities[self.lang] or {}
        local global_priorities = user_priorities["*"] or {}
        local priorities = vim.tbl_extend('keep', lang_priorities, global_priorities)
        if next(priorities) == nil then return iter end

        return function(end_line)
            local capture, captured_node, metadata, match, tree = iter(end_line)
            if capture then
                local name = self.captures[capture]
                local priority = priorities[name]
                if priority then
                    metadata.priority = priority
                end
            end
            return capture, captured_node, metadata, match, tree
        end
    end
end

--- Override the treesitter highlighter to patch capture priorities.
--- You can override a specific hl_group for all languages by using `*`.
---
--- ```lua
--- require("plugins.treesitter.patch_priorities").override({
---     ["*"] = { comment = 98 }
--- })
--- ```
---
--- @param priorities UserPriorities
function M.override(priorities)
    user_priorities = priorities or {}

    local treesitter_new = vim.treesitter.highlighter.new
    function vim.treesitter.highlighter.new(tree, opts)
        local highlighter = treesitter_new(tree, opts)

        local ok, query = pcall(highlighter.get_query, highlighter, tree:lang())
        if ok then patch_query(getmetatable(query:query())) end

        -- ! Restore original constructor after patching
        vim.treesitter.highlighter.new = treesitter_new
        return highlighter
    end
end

return M
