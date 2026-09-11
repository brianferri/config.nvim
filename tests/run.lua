-- Run with: nvim --headless -c 'luafile tests/run.lua'
--
-- ! Report through stderr: `print` in a headless session queues a hit-enter
-- ! prompt once the output outgrows the message area, and `:cq` never runs
local t = require("tests.harness")

for _, spec in ipairs({
    "search_replace_spec",
    "replace_write_spec",
    "better_comments_spec",
}) do require("tests.suites." .. spec) end

if #t.failures == 0 then
    io.stderr:write("ok\n")
    vim.cmd("qa!")
end

for _, failure in ipairs(t.failures) do
    io.stderr:write("FAIL " .. failure .. "\n")
end
vim.cmd(("cq %d"):format(#t.failures))
