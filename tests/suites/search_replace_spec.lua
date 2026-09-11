local t = require("tests.harness")
local sr = require("plugins.telescope.search_replace")

t.suite("search_replace", function()
    t.test("plain text is a search, skip replace", function()
        local spec = sr._parse_prompt_regex("needle")
        t.eq(spec.is_replace, false)
        t.eq(spec.search, "needle")
    end)

    t.test("substitute prompt splits into range, search, replace and flags", function()
        local spec = sr._parse_prompt_regex(":%s/foo/bar/gi")
        t.eq(spec.is_replace, true)
        t.eq(spec.range, "%")
        t.eq(spec.search, "foo")
        t.eq(spec.replace, "bar")
        t.eq(spec.flags, "gi")
    end)

    t.test("an escaped separator stays inside the search", function()
        local spec = sr._parse_prompt_regex(":s/a\\/b/c/")
        t.eq(spec.search, "a\\/b")
        t.eq(spec.replace, "c")
    end)

    t.test("an unterminated substitute falls back to a search", function()
        local spec = sr._parse_prompt_regex(":s/foo")
        t.eq(spec.is_replace, false)
    end)

    t.test("an absent or whole-file range covers every line", function()
        t.eq({ sr._parse_range("", 42) }, { 1, 42 })
        t.eq({ sr._parse_range("%", 42) }, { 1, 42 })
    end)

    t.test("numeric ranges resolve to themselves", function()
        t.eq({ sr._parse_range("7", 42) }, { 7, 7 })
        t.eq({ sr._parse_range("2,5", 42) }, { 2, 5 })
    end)

    t.test("the last-line address resolves to the line count", function()
        t.eq({ sr._parse_range("$", 42) }, { 42, 42 })
        t.eq({ sr._parse_range("2,$", 42) }, { 2, 42 })
    end)

    t.test("an unresolvable range refuses instead of widening", function()
        t.is_nil(sr._parse_range(".,+3", 42))
        t.is_nil(sr._parse_range("'<,'>", 42))
        t.is_nil(sr._parse_range("/pat/", 42))
    end)

    t.test("neighbouring matches merge into one hunk", function()
        t.eq(sr._build_hunks(20, { 5, 6 }), { { start = 2, finish = 9 } })
    end)

    t.test("distant matches stay separate", function()
        t.eq(sr._build_hunks(40, { 5, 30 }), {
            { start = 2, finish = 8 },
            { start = 27, finish = 33 },
        })
    end)

    t.test("hunks stay inside the file", function()
        t.eq(sr._build_hunks(3, { 1 }), { { start = 1, finish = 3 } })
    end)
end)
