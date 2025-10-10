local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.completion.completionItem.snippetSupport = true

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
        "phpactor",
        "tailwindcss",
        "asm_lsp",
        "bashls",
        "emmet_language_server",
        "eslint",
    },
})

-- Some lsps may require certain configurations or overrides
require("configs.lsps.vue")
