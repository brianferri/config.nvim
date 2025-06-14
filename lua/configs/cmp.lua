local cmp = require("cmp")
local luasnip = require("luasnip")

cmp.setup({
    window = {
        completion = {
            border = 'rounded',
            scrollbar = true,

        },
        documentation = {
            border = 'rounded',
            scrollbar = '║',
        },
    },
    snippet = {
        expand = function(args)
            luasnip.lsp_expand(args.body)
        end,
    },
    mapping = cmp.mapping.preset.insert({
        ["<Tab>"] = cmp.mapping.confirm {
            behavior = cmp.ConfirmBehavior.Insert,
            select = true,
        },
    }),
    sources = cmp.config.sources({
        { name = "nvim_lua" },
        { name = "nvim_lsp" },
        { name = "luasnip" },
        { name = "buffer" },
        { name = "path" },
    }),
})

