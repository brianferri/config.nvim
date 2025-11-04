# config.nvim

A modular Neovim configuration in Lua, organized into “configs” and plugin‑specific modules.

## Overview

This repository provides a structured Neovim configuration, broken into separate modules for LSPs, UI, key mappings, plugin integrations, etc.
Its goal is to be clean, maintainable, and easily extendable.

## Requirements

* Neovim 0.11+
* Language servers, debuggers, etc., installed separately (this config assumes they exist or will be installed via e.g. `mason.nvim`)
  * You will need `tree-sitter-cli`, `nodejs`, `npm`, `rust`, `cargo`, `go`, `zig`, `gcc/g++` to get started with this config

## Installation

1. Clone this repo into your Neovim config directory (e.g. `~/.config/nvim`):

   ```bash
   git clone https://github.com/brianferri/config.nvim.git ~/.config/nvim
   # You may also want to remove the `.git` from the dir
   rm -rf ~/.config/nvim/.git
   ```

2. Boot Neovim; your plugin manager should pick up `init.lua` and load everything.

3. Run `:checkhealth` to see if anything is missing (LSPs, debug adapters, etc.).

4. Optionally, add or override modules (see [Customization](#customization-and-extending) below).

## How It Works / Loading Order

1. `init.lua` loads the plugin manager, keybinds and setup specific vim options.
2. After plugin setup, module scripts from `lua/configs/` are required in a predefined order (or lazily according to the `lua/plugins/init.lua`).
3. Each module may call `require("xxx").setup(...)` or configure autocommands, keymaps, etc.
4. Plugin extensions in `lua/plugins/` supplement or override default plugin behavior (for example, custom telescope commands).

The separation helps keep concerns modular (LSP config separate from UI config, etc.).

## Customization and Extending

You can easily override or add your own config modules:

* To add another LSP (say `rust.lua`), create `lua/configs/lsps/rust.lua` with your setup logic.
  * Require the new lsp configuration in `lua/configs/lspconfig.lua`
* To override existing modules, you can either:
  * Fork and edit the relevant file, or
  * In your personal config, `require` them and apply patches (e.g. modify the returned table)
* For plugin-specific extensions (e.g. custom `telescope` pickers), put files in the `lua/plugins/` area following existing patterns.

## Plugin Modules / Highlights

Here are some of the modules and what they typically handle:

| Module                        | Purpose                                                     |
| ----------------------------- | ----------------------------------------------------------- |
| `configs/lsps/`               | LSP Specific setups                                         |
| `configs/cmp.lua`             | Setup `nvim-cmp` (completion)                               |
| `configs/dap.lua`             | Debug Adapter Protocol configuration                        |
| `configs/gitsigns.lua`        | Git integration overlays (signs, hunks)                     |
| `configs/ibl.lua`             | Indentation, blank lines, guides                            |
| `configs/keybinds.lua`        | Global keymaps and leader mappings                          |
| `configs/lspconfig.lua`       | Core LSP client / server mapping logic                      |
| `configs/nvimtree.lua`        | File tree / explorer plugin                                 |
| `configs/render-markdown.lua` | Markdown render / preview settings                          |
| `configs/telescope.lua`       | Telescope / fuzzy‑finder configuration                      |
| `configs/treesitter.lua`      | Treesitter syntax parsing / highlighting                    |
| `configs/vscode-theme.lua`    | Theme / colorscheme setup, mimicking VSCode styling         |

Plugin extension modules:

* `plugins/dap/run.lua`: extra commands or helpers to launch / run debugging sessions
* `plugins/telescope/`
  * `open_recent.lua`: open recently viewed files
  * `search_replace.lua`: search (and replace) diff view
* `plugins/treesitter/patch_priorities.lua`: a monkey patch to override treesitter extmark priority metadata
* `plugins/vscode-theme/`
  * `better_comments.lua`: Highlights comments according to patterns
  * `trailing_whitespaces.lua`: Highlights trailing whitespaces and facilitates removal

## Usage Tips

* Use `:Lazy` to inspect loaded plugins.
* Use `:Mason` (`:MasonLog`) to inspect your LSPs, DAPs, Linters, etc.
* Use `:checkhealth` to verify LSP, treesitter, and other modules.

