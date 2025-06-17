return {
    {
        "nvim-telescope/telescope.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
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
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function() require "configs.ntree" end,
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
        "norcalli/nvim-colorizer.lua",
        config = function() require "colorizer".setup() end,
    },
    {
        "Mofiqul/vscode.nvim",
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
        "rcarriga/nvim-dap-ui",
        dependencies = {
            "mfussenegger/nvim-dap",
            "nvim-neotest/nvim-nio",
            "mfussenegger/nvim-dap-python",
        }
    },
    {
        "RRethy/vim-illuminate"
    },
    -- Setup Specific Plugins
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
