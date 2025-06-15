local map = function(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { noremap = true, silent = true, desc = desc })
end

vim.o.keymodel = "startsel,stopsel"
local all_modes = { 'i', 'n', 'v' }

-- Core Telescope and File Navigation
map(all_modes, '<M-p>', "<cmd>Telescope find_files<CR>", "Telescope: Find Files (file palette)")
map(all_modes, '<M-S-p>', "<cmd>Telescope commands<CR>", "Telescope: Commands (command palette)")
map(all_modes, '<C-b>', "<cmd>NvimTreeToggle<CR>", "Toggle File Tree")
map(all_modes, '<C-g>', "<cmd>FloatermNew lazygit<CR>", "Open LazyGit")
map(all_modes, '<C-,>', "<cmd>FloatermNew nvim ~/.config/nvim<CR>", "Open Nvim Config")

-- Quit, Write, Search
map(all_modes, '<C-q>', "<cmd>qa<CR>", "Quit All")
map(all_modes, '<C-w>', "<cmd>q<CR>", "Close Window")
map(all_modes, '<C-s>', "<cmd>w<CR>", "Write File")
map(all_modes, '<C-f>', "<ESC>/", "Search")

-- Select All, Move Lines, Selection Manipulation
-- TODO add comment on selection/line
map(all_modes, '<C-a>', "<ESC>ggVG", "Select All")

map({ 'i', 'n' }, '<M-C-S-Up>', '<ESC>yyP', "Duplicate Line Up")
map({ 'i', 'n' }, '<M-C-S-Down>', '<ESC>yyp', "Duplicate Line Down")
map('v', '<M-C-S-Up>', ":t '<-1<CR>gv=gv", "Duplicate Selection Up")
map('v', '<M-C-S-Down>', ":t '>+0<CR>gv=gv", "Duplicate Selection Down")

map({ 'i', 'n' }, '<M-Up>', '<cmd>m .-2<CR>', "Move Line Up")
map({ 'i', 'n' }, '<M-Down>', '<cmd>m .+1<CR>', "Move Line Down")
map('v', '<M-Up>', ":m '<-2<CR>gv=gv", "Move Selection Up")
map('v', '<M-Down>', ":m '>+1<CR>gv=gv", "Move Selection Down")

map(all_modes, '<M-BS>', "<ESC>daw", "Delete A Word")
map('v', '<Tab>', ">gv", "Indent Selection")
map('v', '<S-Tab>', "<gv", "Unindent Selection")
map('v', '<BS>', '"_d', "Delete Selection")

-- Copy/Cut/Paste/Undo
map(all_modes, '<C-v>', '<ESC>pi', "Paste")
map(all_modes, '<C-z>', '<ESC>ui', "Undo")

map({ 'i', 'n' }, '<C-x>', '<ESC>dd<ESC>i', "Cut")
map('v', '<C-c>', '"+y<ESC>i', "Copy")
map('v', '<C-x>', 'd<ESC>i', "Cut")

-- LSP Bindings
map(all_modes, '<C-k>', function() vim.lsp.buf.hover { border = 'rounded' } end, "LSP Hover")
map(all_modes, '<C-LeftMouse>', vim.lsp.buf.implementation, "LSP Implementation")
map(all_modes, '<C-r>', vim.lsp.buf.rename, "LSP Rename")
map(all_modes, '<C-.>', vim.lsp.buf.code_action, "LSP Code Action")
map(all_modes, '<C-S-i>', function() vim.lsp.buf.format { async = true } end, "LSP Format")

-- Visual Multi
map(all_modes, '<C-d>', '<ESC><Plug>(VM-Find-Under)', "VM: Select Next Word Down")
map(all_modes, '<C-S-d>', '<ESC><Plug>(VM-Select-All)', "VM: Select All Occurrences")
