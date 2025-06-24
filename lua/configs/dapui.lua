require("dapui").setup()
local dap = require("dap")

dap.adapters.lldb = {
    type = "server",
    port = "${port}",
    executable = {
        command = "codelldb",
        args = { "--port", "${port}" },
    },
}

-- Custom commands
require("plugins.dap.run").setup({
    adapter_options = {
        codelldb = {
            request = "launch",
            adapter = dap.adapters.lldb,
            config = {
                stopOnEntry = false,
                args = {},
            },
        },
    },
})
