local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- All Modes
A = { 'i', 'n', 'v' }

map(A, '<C-p>', "<ESC>:Telescope find_files<CR>", opts)
map(A, '<C-S-p>', "<ESC>:Telescope commands<CR>", opts)
map(A, '<C-b>', "<ESC>:NvimTreeToggle<CR>", opts)
map(A, '<C-g>', "<ESC>:FloatermNew lazygit<CR>", opts)

map(A, '<C-q>', "<ESC>:qa<CR>", opts)
map(A, '<C-w>', "<ESC>:q<CR>", opts)
map(A, '<C-s>', "<ESC>:w<CR>i<Right>", opts)
map(A, '<C-f>', "<ESC>/", opts)

map(A, '<C-a>', "<ESC>ggVG", opts)
map(A, '<M-Up>', '<ESC>ddkP', opts)
map(A, '<M-Down>', '<ESC>ddjP', opts)

map(A, "<C-k>", function() vim.lsp.buf.hover { border = 'rounded' } end, opts)
map(A, "<C-LeftMouse>", vim.lsp.buf.implementation, opts)
map(A, "<C-r>", vim.lsp.buf.rename, opts)
map(A, "<C-.>", vim.lsp.buf.code_action, opts)
-- map(A, "gd", vim.lsp.buf.definition, opts)
-- map(A, "<C-S-r>", vim.lsp.buf.references, opts)
map(A, "<C-S-i>", function() vim.lsp.buf.format { async = true } end, opts)
