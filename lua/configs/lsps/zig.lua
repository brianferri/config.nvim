-- ? git clone https://github.com/llogick/zigscient-next ~/.local/share/nvim/mason/packages/zigscient
-- * `ZIG_DEBUG_CMD=1 ZIG_LIB_DIR=./lib zig build -Doptimize=ReleaseFast`

-- ? ~/.local/share/nvim/mason/packages/zigscient
local zigscient = vim.fn.stdpath('data') .. "/mason/packages/zigscient/zig-out/bin/zigscient"

vim.lsp.config('zigscient', {
    cmd = { zigscient },
    filetypes = { 'zig', 'zir', 'zon' },
    root_markers = { 'zls.json', 'build.zig', '.git' },
    workspace_required = false,
})
vim.lsp.enable({ 'zigscient' })
