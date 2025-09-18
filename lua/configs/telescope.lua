require("plugins.telescope.open_recent").setup({
    directory_preview = {
        list_command = "eza",
        arguments = { "-lh", "--icons=always", "--color=never" },
    }
})
