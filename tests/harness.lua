local M = { failures = {} }

--- @param label string
--- @param fn fun()
function M.suite(label, fn)
    M.label = label
    fn()
end

--- @param name string
--- @param fn fun()
function M.test(name, fn)
    local ok, err = pcall(fn)
    if ok then return end
    table.insert(M.failures, string.format("%s / %s: %s", M.label, name, err))
end

--- Assertions hand back what they were given, narrowed, so a checked value can
--- carry straight into the next expression.
--- @see LuaLsDocs [`@generic`](https://luals.github.io/wiki/annotations/#generic)

--- @generic T
--- @param actual? T
--- @param expected any
--- @return T
function M.eq(actual, expected)
    if vim.deep_equal(actual, expected) then return actual end
    error(string.format("expected %s, got %s", vim.inspect(expected), vim.inspect(actual)), 2)
end

--- @param value any
function M.is_nil(value)
    if value == nil then return end
    error(string.format("expected nil, got %s", vim.inspect(value)), 2)
end

--- @generic T
--- @param value? T
--- @return T
function M.truthy(value)
    if value then return value end
    error(string.format("expected a truthy value, got %s", vim.inspect(value)), 2)
end

--- @param value? string
--- @param pattern string
--- @return string
function M.matches(value, pattern)
    if value ~= nil then
        local captured = value:match(pattern)
        if captured ~= nil then return captured end
    end
    error(string.format("expected %s to match %s", vim.inspect(value), vim.inspect(pattern)), 2)
end

return M
