local t = require("tests.harness")
local sr = require("plugins.telescope.search_replace")

--- @param lines string[]
--- @return string
local function scratch_file(lines)
    local path = vim.fn.tempname() .. ".txt"
    vim.fn.writefile(lines, path)
    return path
end

--- @param path string
--- @param prompt string
local function entry_for(path, prompt)
    return { path = path, value = path, prompt = sr._parse_prompt_regex(prompt) }
end

t.suite("search_replace writes", function()
    t.test("an unloaded file is rewritten in place", function()
        local path = scratch_file({ "alpha", "beta", "alpha" })
        local ok, err = sr._apply_replacement_to_file(entry_for(path, ":%s/alpha/omega/"))
        t.truthy(ok)
        t.is_nil(err)
        t.eq(vim.fn.readfile(path), { "omega", "beta", "omega" })
    end)

    t.test("a numeric range touches only its own lines", function()
        local path = scratch_file({ "a", "a", "a" })
        t.truthy(sr._apply_replacement_to_file(entry_for(path, ":2s/a/b/")))
        t.eq(vim.fn.readfile(path), { "a", "b", "a" })
    end)

    t.test("the last-line address resolves per file", function()
        local path = scratch_file({ "a", "a", "a" })
        t.truthy(sr._apply_replacement_to_file(entry_for(path, ":$s/a/b/")))
        t.eq(vim.fn.readfile(path), { "a", "a", "b" })
    end)

    t.test("an unresolvable range refuses the write", function()
        local path = scratch_file({ "a", "a" })
        local ok, err = sr._apply_replacement_to_file(entry_for(path, ":'<,'>s/a/b/"))
        t.eq(ok, false)
        t.matches(err, "unsupported range")
        t.eq(vim.fn.readfile(path), { "a", "a" })
    end)

    t.test("a loaded buffer takes the edit and stays in sync", function()
        local path = scratch_file({ "alpha", "beta" })
        vim.cmd("silent edit " .. vim.fn.fnameescape(path))
        local bufnr = vim.api.nvim_get_current_buf()

        t.truthy(sr._apply_replacement_to_file(entry_for(path, ":%s/alpha/omega/")))
        t.eq(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), { "omega", "beta" })
        t.eq(vim.fn.readfile(path), { "omega", "beta" })
        t.eq(vim.bo[bufnr].modified, false)

        vim.cmd("silent undo")
        t.eq(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), { "alpha", "beta" })
        vim.cmd("bwipeout!")
    end)

    t.test("a buffer with unsaved edits is left alone", function()
        local path = scratch_file({ "alpha" })
        vim.cmd("silent edit " .. vim.fn.fnameescape(path))
        local bufnr = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "alpha", "handwritten" })

        local ok, err = sr._apply_replacement_to_file(entry_for(path, ":%s/alpha/omega/"))
        t.eq(ok, false)
        t.matches(err, "unsaved")
        t.eq(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), { "alpha", "handwritten" })
        t.eq(vim.fn.readfile(path), { "alpha" })
        vim.cmd("bwipeout!")
    end)

    t.test("a spec that changes nothing reports so", function()
        local path = scratch_file({ "alpha" })
        local ok, err = sr._apply_replacement_to_file(entry_for(path, ":%s/zeta/omega/"))
        t.eq(ok, false)
        t.eq(err, "no changes")
    end)
end)
