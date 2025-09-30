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
    }
})
