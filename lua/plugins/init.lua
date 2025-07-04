return {
    {
        "nvim-telescope/telescope.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function() require "configs.telescope" end
    },
    {
        "akinsho/git-conflict.nvim",
        version = "*",
        config = true
    },
    {
        "akinsho/bufferline.nvim",
        version = "*",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function() require "configs.bufferline" end
    },
    {
        "nvim-lualine/lualine.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function() require "configs.lualine" end
    },
    {
        "nvim-tree/nvim-tree.lua",
        version = "*",
        priority = 999,
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function() require "configs.nvimtree" end,
    },
    {
        "nvim-treesitter/nvim-treesitter",
        branch = "master",
        lazy = false,
        run = ":TSUpdate",
        config = function() require "configs.treesitter" end,
    },
    {
        "neovim/nvim-lspconfig",
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
        "Mofiqul/vscode.nvim",
        priority = 1000,
        config = function() require "configs.vscode" end
    },
    {
        "voldikss/vim-floaterm"
    },
    {
        "lewis6991/gitsigns.nvim",
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
        "RRethy/vim-illuminate"
    },
    {
        "kylechui/nvim-surround",
        version = "^3.0.0",
        event = "VeryLazy",
        config = function() require "nvim-surround".setup() end
    },
    -- Setup Specific Plugins
    {
        "norcalli/nvim-colorizer.lua",
        config = function() require "colorizer".setup() end,
    },
    {
        "lukas-reineke/indent-blankline.nvim",
        main = "ibl",
        dependencies = { {
            "HiPhish/rainbow-delimiters.nvim",
            submodules = false,
        } },
        config = function() require "configs.ibl" end
    },
    {
        "linux-cultist/venv-selector.nvim",
        lazy = false,
        branch = "regexp",
        opts = {},
    },
}
