local map = function(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { noremap = true, silent = true, desc = desc })
end

vim.o.keymodel = "startsel,stopsel"
local all_modes = { 'i', 'n', 'v' }

-- Core Telescope and File Navigation
map(all_modes, '<C-p>', "<cmd>Telescope find_files<CR>", "Telescope: Find Files (file palette)")
map(all_modes, '<M-p>', "<cmd>Telescope commands<CR>", "Telescope: Commands (command palette)")
map(all_modes, '<C-b>', "<cmd>NvimTreeToggle<CR>", "Toggle File Tree")
map(all_modes, '<C-g>', "<cmd>FloatermNew lazygit<CR>", "Open LazyGit")

-- Quit, Write, Search
map(all_modes, '<C-q>', "<cmd>qa<CR>", "Quit All")
map(all_modes, '<C-w>', "<cmd>q<CR>", "Close Window")
map(all_modes, '<C-s>', "<cmd>w<CR>", "Write File")
map(all_modes, '<C-f>', "<ESC>/", "Search")

-- Select All, Move Lines, Word Manipulation
map(all_modes, '<C-a>', "<ESC>ggVG", "Select All")
map(all_modes, '<M-Up>', '<cmd>m .-2<CR>==', "Move Line Up")
map(all_modes, '<M-Down>', '<cmd>m .+1<CR>==', "Move Line Down")

map('v', '<M-Up>', ":m '<-2<CR>gv=gv", "Move Selection Up")
map('v', '<M-Down>', ":m '>+1<CR>gv=gv", "Move Selection Down")
map('v', '<Tab>', ">gv", "Indent Selection")
map('v', '<S-Tab>', "<gv", "Unindent Selection")
map('v', '<BS>', '"_d', "Delete Selection")

-- Copy/Cut/Paste/Undo
map(all_modes, '<C-v>', '<Esc>pi', "Paste")
map(all_modes, '<C-z>', '<Esc>ui', "Undo")

map('v', '<C-c>', '"+y<Esc>i', "Copy")
map('v', '<C-x>', 'd<Esc>i', "Cut")

-- LSP Bindings
map(all_modes, '<C-k>', function() vim.lsp.buf.hover { border = 'rounded' } end, "LSP Hover")
map(all_modes, '<C-LeftMouse>', vim.lsp.buf.implementation, "LSP Implementation")
map(all_modes, '<C-r>', vim.lsp.buf.rename, "LSP Rename")
map(all_modes, '<C-.>', vim.lsp.buf.code_action, "LSP Code Action")
-- map(all_modes, 'gd', vim.lsp.buf.definition, "LSP Goto Definition")
-- map(all_modes, '<C-S-r>', vim.lsp.buf.references, "LSP References")
map(all_modes, '<C-S-i>', function() vim.lsp.buf.format { async = true } end, "LSP Format")
