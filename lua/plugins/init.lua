return {
    {
        "nvim-telescope/telescope.nvim",
        -- ? `configs.telescope` is what defines `SearchReplace` and `OpenRecent`,
        -- ? so both have to be listed here for the stubs to reach it
        cmd = { "Telescope", "SearchReplace", "OpenRecent" },
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function() require "configs.telescope" end
    },
    {
        "3rd/image.nvim",
        build = false,
        event = "VeryLazy",
        opts = { processor = "magick_cli" },
        dependencies = { "nvim-telescope/telescope.nvim" }
    },
    {
        "akinsho/git-conflict.nvim",
        version = "*",
        event = "VeryLazy",
        config = true
    },
    {
        'MeanderingProgrammer/render-markdown.nvim',
        ft = "markdown",
        dependencies = {
            'nvim-tree/nvim-web-devicons',
            'nvim-treesitter/nvim-treesitter',
        },
        config = function() require "configs.render-markdown" end
    },
    {
        "akinsho/bufferline.nvim",
        version = "*",
        event = "VeryLazy",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function() require "configs.bufferline" end
    },
    {
        "nvim-lualine/lualine.nvim",
        event = "VeryLazy",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function() require "configs.lualine" end
    },
    {
        -- ! Making it eager since its config is what clears `netrw`,
        -- ! and a lazy load would let netrw claim the first directory opened
        "nvim-tree/nvim-tree.lua",
        version = "*",
        lazy = false,
        priority = 999,
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function() require "configs.nvimtree" end,
    },
    {
        "nvim-treesitter/nvim-treesitter",
        branch = "main",
        lazy = false,
        build = ":TSUpdate",
        config = function() require "configs.treesitter" end,
    },
    {
        "neovim/nvim-lspconfig",
        event = { "BufReadPre", "BufNewFile" },
        cmd = { "Mason", "MasonLog", "LspInfo" },
        dependencies = {
            { "williamboman/mason.nvim",           config = true },
            { "williamboman/mason-lspconfig.nvim", config = true },
        },
        config = function() require "configs.lspconfig" end,
    },
    {
        "folke/lazydev.nvim",
        ft = "lua",
        config = function() require "configs.lazydev" end,
    },
    {
        "hrsh7th/nvim-cmp",
        event = { "InsertEnter", "CmdlineEnter" },
        dependencies = {
            "hrsh7th/cmp-nvim-lsp",
            "hrsh7th/cmp-buffer",
            "hrsh7th/cmp-path",
            "hrsh7th/cmp-cmdline",
            "L3MON4D3/LuaSnip",
            "saadparwaiz1/cmp_luasnip",
        },
        config = function() require "configs.cmp" end
    },
    {
        "voldikss/vim-floaterm",
        cmd = { "FloatermNew", "FloatermToggle", "FloatermNext", "FloatermPrev" },
    },
    {
        "lewis6991/gitsigns.nvim",
        event = { "BufReadPre", "BufNewFile" },
        config = function() require "configs.gitsigns" end
    },
    {
        "mg979/vim-visual-multi",
        branch = "master",
        event = "VeryLazy",
    },
    {
        "mfussenegger/nvim-dap",
        event = "VeryLazy",
        dependencies = {
            "rcarriga/nvim-dap-ui",
            "nvim-neotest/nvim-nio",
            "theHamsta/nvim-dap-virtual-text",
        },
        config = function() require "configs.dap" end
    },
    {
        "RRethy/vim-illuminate",
        event = { "BufReadPost", "BufNewFile" },
    },
    {
        "kylechui/nvim-surround",
        version = "^3.0.0",
        event = "VeryLazy",
        config = function() require "nvim-surround".setup() end
    },
    {
        "Mofiqul/vscode.nvim",
        priority = 1000,
        config = function() require "configs.vscode-theme" end
    },
    {
        "norcalli/nvim-colorizer.lua",
        event = { "BufReadPost", "BufNewFile" },
        config = function() require "colorizer".setup() end,
    },
    {
        "lukas-reineke/indent-blankline.nvim",
        main = "ibl",
        event = { "BufReadPost", "BufNewFile" },
        dependencies = { {
            "HiPhish/rainbow-delimiters.nvim",
            submodules = false,
        } },
        config = function() require "configs.ibl" end
    },
    {
        "linux-cultist/venv-selector.nvim",
        ft = "python",
        opts = {},
    },
}
