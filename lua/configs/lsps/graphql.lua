--- @see https://spec.graphql.org/draft/#sec-Introspection

-- ? ~/.local/share/nvim/mason/packages/graphql-language-service-cli/node_modules/graphql-language-service-cli/bin/graphql.js
local graphql_lsp_path = vim.fn.stdpath('data') ..
    "/mason/packages/graphql-language-service-cli/node_modules/graphql-language-service-cli/bin/graphql.js"

vim.lsp.config('graphql', {
    filetypes = { "graphql", "gql" },
    root_markers = {
        ".graphqlrc",
        ".graphqlrc.yml",
        ".graphqlrc.json",
        ".graphqlrc.js",
        "graphql.config.js",
        "graphql.config.json",
    },
    cmd =
    ---@param dispatchers vim.lsp.rpc.Dispatchers
    ---@param config vim.lsp.ClientConfig
    ---@return vim.lsp.rpc.PublicClient
        function(dispatchers, config)
            local cmd = { "node", graphql_lsp_path, "server", "-m", "stream" }
            if config.root_dir then
                table.insert(cmd, "-c")
                table.insert(cmd, config.root_dir)
            end
            return vim.lsp.rpc.start(cmd, dispatchers, {
                cwd = config.root_dir
            })
        end,
})
vim.lsp.enable({ 'graphql' })

require("plugins.lspconfig.graphql").setup()
