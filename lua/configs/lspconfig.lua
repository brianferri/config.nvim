local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.completion.completionItem.snippetSupport = true

-- ! https://github.com/neovim/neovim/issues/23291
capabilities.workspace.didChangeWatchedFiles.dynamicRegistration = false

require("mason").setup()
require("mason-lspconfig").setup({
    ensure_installed = {
        "lua_ls",
        "rust_analyzer",
        "clangd",
        "zls",
        "vtsls",
        "vue_ls",
        "html",
        "cssls",
        "gopls",
        "pyright",
        "intelephense",
        "tailwindcss",
        "bashls",
        "emmet_language_server",
        "eslint",
    },
})

-- Some lsps may require certain configurations or overrides
require("configs.lsps.vue")
require("configs.lsps.graphql")

-- Neovim 0.12 removed :LspInfo from nvim-lspconfig.
-- Provide a lightweight compatibility command for this config.
vim.api.nvim_create_user_command("LspInfo", function()
    local bufnr = vim.api.nvim_get_current_buf()
    local clients = vim.lsp.get_clients({ bufnr = bufnr })

    if #clients == 0 then
        vim.notify("No active LSP clients for current buffer.", vim.log.levels.INFO)
        return
    end

    local lines = { "Active LSP clients:" }
    for _, client in ipairs(clients) do
        local root = client.config.root_dir or "(no root)"
        lines[#lines + 1] = string.format("- %s (id=%d, root=%s)", client.name, client.id, root)
    end

    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "LspInfo" })
end, { desc = "Show active LSP client information for current buffer" })
