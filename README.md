# config.nvim

## Requirements

* Neovim 0.11+
* Language servers, debuggers, etc., installed separately (this config assumes they exist or will be installed via `mason.nvim`)
  * You will need `tree-sitter-cli`;
  - `nodejs`, `npm`, `rust`, `cargo`, `go`, `zig`, `gcc/g++` for the default [lsp configs](./lua/configs/lspconfig.lua);
> remove any lsps from the [lsp configs](./lua/configs/lspconfig.lua) you don't intend to use/don't want to install the binaries for before running `nvim`

## Installation

1. Clone this repo into your Neovim config directory:
   ```bash
   git clone https://github.com/brianferri/config.nvim.git ~/.config/nvim
   # You may also want to remove the `.git` from the dir
   rm -rf ~/.config/nvim/.git
   ```
2. Boot Neovim; The plugin manager will pick up `init.lua` and load everything.
3. Run `:checkhealth` to see if anything is missing (LSPs, debug adapters, etc.).
4. Optionally, add or override modules (see [Customization](#customization-and-extending) below).

## Usage Tips

* Use `:Lazy` to inspect loaded plugins.
* Use `:Mason` (`:MasonLog`) to inspect LSPs, DAPs, Linters, etc.

