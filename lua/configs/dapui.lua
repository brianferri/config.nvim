require("dapui").setup()
local dap = require("dap")

dap.adapters.lldb = {
    type = "server",
    port = "${port}",
    executable = {
        command = "lldb",
        args = { "--port", "${port}" },
    },
}

-- Custom commands
require("plugins.dap.run").setup({
    configurations = {
        codelldb = {
            name = "Launch",
            type = "lldb",
            request = "launch",
        },
    },
})
