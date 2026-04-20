-- TODO: Wait for this :) https://github.com/MeanderingProgrammer/render-markdown.nvim/pull/617
vim.api.nvim_create_autocmd("FileType", {
    pattern = "markdown",
    callback = function()
        vim.opt_local.wrap = false
    end,
})

require('render-markdown').setup({
    render_modes = true,
    sign = { enabled = false },
    completions = { lsp = { enabled = true } },
    heading = {
        width = "block",
    },
    code = {
        width = "block",
        border = "thin",
    },
    pipe_table = {
        preset = "round",
        cell = "overlay",
    },
})
