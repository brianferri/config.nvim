local os = require("os")
local dap = require("dap")
local dapui = require("dapui")

dapui.setup()
dap.listeners.before.attach.dapui_config = dapui.open
dap.listeners.before.launch.dapui_config = dapui.open
dap.listeners.before.event_terminated.dapui_config = dapui.close
dap.listeners.before.event_exited.dapui_config = dapui.close

dap.adapters.codelldb = {
    type = "server",
    port = "${port}",
    executable = {
        command = os.getenv("HOME") .. "/.local/share/nvim/mason/bin/codelldb",
        args = { "--port", "${port}" },
    },
}

-- Custom commands
require("plugins.dap.run").setup({
    configurations = {
        codelldb = {
            name = "Launch",
            type = "codelldb",
            request = "launch",

        },
    },
})
