require("bufferline").setup({
    options = {
        diagnostics = "nvim_lsp",
        close_command = "bdelete %d",
        right_mouse_command = "bdelete! %d",

        close_icon = "×",
        buffer_close_icon = "×",
        left_trunc_marker = "",
        right_trunc_marker = "",
        modified_icon = "●",

        show_tab_indicators = true,

        hover = {
            enabled = true,
            delay = 10,
            reveal = { 'close' }
        },

        offsets = { { filetype = "NvimTree", text = "Workspace", text_align = "center" } },
        show_close_icon = false,
    },
    highlights = {
        fill = { bg = "#1e1e1e" },
        background = { fg = "#808080", },
        buffer_visible = { fg = "#a0a0a0", },
        buffer_selected = {
            fg = "#ffffff",
            bg = "#252526",
            bold = true,
            underline = true,
        },
        modified = { fg = "#808080", },
        modified_selected = {
            fg = "#ffffff",
            bg = "#252526",
            bold = true,
            underline = true,

        },
        separator = { fg = "#2d2d2d", },
        separator_selected = {
            fg = "#2d2d2d",
            bg = "#252526",
            bold = true,
            underline = true,

        },
        close_button = { fg = "#808080", },
        close_button_selected = {
            fg = "#ffffff",
            bg = "#252526",
            bold = true,
            underline = true,
        },

        error = { fg = "#e1554f" },
        error_selected = { fg = "#e1554f", bold = true, underline = true },

        warning = { fg = "#dcdcaf" },
        warning_selected = { fg = "#dcdcaf", bold = true, underline = true },

        info = { fg = "#3678c4" },
        info_selected = { fg = "#3678c4", bold = true, underline = true },

        hint = { fg = "#74985d" },
        hint_selected = { fg = "#74985d", bold = true, underline = true },
    }
})
