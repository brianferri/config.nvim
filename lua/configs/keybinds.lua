local map = function(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { noremap = true, silent = true, desc = desc })
end

vim.o.keymodel = "startsel,stopsel"
local all_modes = { 'i', 'n', 'v' }

-- Core Telescope and File Navigation
map(all_modes, '<C-b>', "<CMD>NvimTreeToggle<CR>", "Toggle File Tree")
map(all_modes, '<C-g>', "<CMD>FloatermNew lazygit<CR>", "Open LazyGit")
map(all_modes, '<C-,>', "<CMD>FloatermNew nvim ~/.config/nvim<CR>", "Open Nvim Config")
map(all_modes, '<M-p>', "<CMD>Telescope find_files<CR>", "Telescope: Find Files (file palette)")
map(all_modes, '<M-S-p>', "<CMD>Telescope commands<CR>", "Telescope: Commands (command palette)")
map(all_modes, '<M-S-]>', "<CMD>BufferLineCycleNext<CR>", "Cycle Next Buffer")
map(all_modes, '<M-S-[>', "<CMD>BufferLineCyclePrev<CR>", "Cycle Previous Buffer")

-- Visual Multi
vim.g.VM_default_mappings = 0
map(all_modes, '<M-d>', '<ESC><Plug>(VM-Find-Under)', "VM: Select Next Word Down")
map(all_modes, '<M-S-d>', '<ESC><Plug>(VM-Select-All)', "VM: Select All Occurrences")

-- Movement
map({ 'i', 'n' }, '<M-Right>', "<ESC>lwi", "Move To Next Word")
map({ 'i', 'n' }, '<M-Left>', "<ESC>bi", "Move To Previous Word")
map('v', '<M-S-Right>', "lw", "Expand Selection To Next Word")
map('v', '<M-S-Left>', "b", "Reduce Selection By A Word")

-- Quit, Write, Search
map(all_modes, '<M-q>', "<CMD>qa<CR>", "Quit All")
map(all_modes, '<M-w>', "<CMD>q<CR>", "Close Window")
map(all_modes, '<M-s>', "<CMD>w<CR>", "Write File")
map(all_modes, '<M-f>', "<ESC>/", "Search In File")
map(all_modes, '<M-S-f>', "<CMD>Telescope live_grep<CR>", "Search All Files")

-- Select All, Move Lines, Selection Manipulation
-- TODO add comment on selection/line
map(all_modes, '<M-a>', "<ESC>ggVG", "Select All")

map({ 'i', 'n' }, '<M-C-S-Up>', '<ESC>yyP', "Duplicate Line Up")
map({ 'i', 'n' }, '<M-C-S-Down>', '<ESC>yyp', "Duplicate Line Down")
map('v', '<M-C-S-Up>', ":t '<-1<CR>gv=gv", "Duplicate Selection Up")
map('v', '<M-C-S-Down>', ":t '>+0<CR>gv=gv", "Duplicate Selection Down")

map({ 'i', 'n' }, '<M-Up>', '<CMD>m .-2<CR>', "Move Line Up")
map({ 'i', 'n' }, '<M-Down>', '<CMD>m .+1<CR>', "Move Line Down")
map('v', '<M-Up>', ":m '<-2<CR>gv=gv", "Move Selection Up")
map('v', '<M-Down>', ":m '>+1<CR>gv=gv", "Move Selection Down")

map(all_modes, '<M-BS>', "<ESC>daw<ESC>i", "Delete A Word")
map('v', '<Tab>', ">gv", "Indent Selection")
map('v', '<S-Tab>', "<gv", "Unindent Selection")
map('v', '<BS>', '"_d', "Delete Selection")

-- Copy/Cut/Paste/Undo/Redo
map(all_modes, '<M-v>', '<ESC>pi', "Paste")
map(all_modes, '<M-z>', '<ESC>ui', "Undo")
map(all_modes, '<M-S-z>', '<ESC><C-r>i', "Redo")

map({ 'i', 'n' }, '<M-x>', '<ESC>dd<ESC>i', "Cut")
map('v', '<M-c>', '"+y<ESC>i', "Copy")
map('v', '<M-x>', 'd<ESC>i', "Cut")

-- LSP Bindings
map(all_modes, '<M-k>', function() vim.lsp.buf.hover { border = 'rounded' } end, "LSP Hover")
map(all_modes, '<M-C-k>', vim.lsp.buf.references, "LSP References")
map(all_modes, '<M-S-k>', vim.lsp.buf.implementation, "LSP Implementation")
map(all_modes, '<F2>', vim.lsp.buf.rename, "LSP Rename")
map(all_modes, '<M-.>', vim.lsp.buf.code_action, "LSP Code Action")
map(all_modes, '<M-S-i>', function() vim.lsp.buf.format { async = true } end, "LSP Format")
