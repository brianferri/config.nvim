--- Shorthand keymap set
--- @param mode string|string[]
--- @param lhs string
--- @param rhs string|function
--- @param desc string
--- @param opts vim.keymap.set.Opts|nil
local map = function(mode, lhs, rhs, desc, opts)
    local conf = { noremap = true, silent = true, desc = desc }
    if opts then vim.tbl_deep_extend('force', conf, opts) end
    vim.keymap.set(mode, lhs, rhs, conf)
end

vim.o.keymodel = "startsel,stopsel"
local all_modes = { 'i', 'n', 'v' }

-- Core Telescope and File Navigation
map(all_modes, '<C-b>', "<CMD>NvimTreeToggle<CR>", "Toggle File Tree")
map(all_modes, '<C-g>', "<CMD>FloatermNew --height=0.9 --width=0.8 lazygit<CR>", "Open LazyGit")
map(all_modes, '<C-,>', "<CMD>FloatermNew nvim ~/.config/nvim<CR>", "Open Nvim Config")
map(all_modes, '<M-p>', "<CMD>Telescope find_files<CR>", "Telescope: Find Files (file palette)")
map(all_modes, '<M-S-p>', "<CMD>Telescope commands<CR>", "Telescope: Commands (command palette)")
map(all_modes, '<M-S-]>', "<CMD>BufferLineCycleNext<CR>", "Cycle Next Buffer")
map(all_modes, '<M-S-[>', "<CMD>BufferLineCyclePrev<CR>", "Cycle Previous Buffer")

-- Visual Multi
vim.g.VM_default_mappings = 0
map({ 'i', 'n' }, '<M-d>', '<ESC><Plug>(VM-Find-Under)', "VM: Select Next Word Down")
map('v', '<M-d>', '<Plug>(VM-Find-Subword-Under)', "VM: Select Next Word Down")
map(all_modes, '<M-S-d>', '<ESC><Plug>(VM-Select-All)', "VM: Select All Occurrences")
map(all_modes, '<C-S-Up>', '<ESC><Plug>(VM-Select-Cursor-Up)', "VM: Start Selecting Up")
map(all_modes, '<C-S-Down>', '<ESC><Plug>(VM-Select-Cursor-Down)', "VM: Start Selecting Down")

-- Split Panes
vim.o.spr = true
vim.o.sb = true
map(all_modes, '<M-\\>', '<CMD>vsplit<CR>', "Vertical Split")
map(all_modes, '<M-->', '<CMD>split<CR>', "Horizontal Split")
map(all_modes, '<M-S-\\>', "<CMD>vsplit <BAR> terminal<CR>i", "Terminal in Vertical Split")
map(all_modes, '<M-S-->', "<CMD>split <BAR> terminal<CR>i", "Terminal in Horizontal Split")
map(all_modes, '<C-Left>', "<ESC><C-w>h", "Move Between Splits Left")
map(all_modes, '<C-Down>', "<ESC><C-w>j", "Move Between Splits Down")
map(all_modes, '<C-Up>', "<ESC><C-w>k", "Move Between Splits Up")
map(all_modes, '<C-Right>', "<ESC><C-w>l", "Move Between Splits Right")

-- Quit, Write, Search
map(all_modes, '<M-q>', "<CMD>qa<CR>", "Quit All")
map(all_modes, '<M-S-w>', "<CMD>q<CR>", "Close Window")
map(all_modes, '<M-w>', "<CMD>bp <BAR> bd #<CR>", "Close Tab")
map(all_modes, '<M-s>', "<CMD>w<CR>", "Write File")
map(all_modes, '<M-S-f>', "<CMD>Telescope live_grep<CR>", "Search All Files")

-- Select All, Move Lines, Selection Manipulation
map(all_modes, '<M-a>', "<ESC>ggVG", "Select All")

map({ 'i', 'n' }, '<M-C-S-Up>', '<ESC>yyP', "Duplicate Line Up")
map({ 'i', 'n' }, '<M-C-S-Down>', '<ESC>yyp', "Duplicate Line Down")
map('v', '<M-C-S-Up>', ":t '<-1<CR>gv=gv", "Duplicate Selection Up")
map('v', '<M-C-S-Down>', ":t '>+0<CR>gv=gv", "Duplicate Selection Down")

map({ 'i', 'n' }, '<M-Up>', '<CMD>m .-2<CR>', "Move Line Up")
map({ 'i', 'n' }, '<M-Down>', '<CMD>m .+1<CR>', "Move Line Down")
map('v', '<M-Up>', ":m '<-2<CR>gv=gv", "Move Selection Up")
map('v', '<M-Down>', ":m '>+1<CR>gv=gv", "Move Selection Down")

map({ 'i', 'n' }, '<M-Right>', "<ESC>ea", "Move To Next Word")
map({ 'i', 'n' }, '<M-Left>', "<ESC>bi", "Move To Previous Word")
map('v', '<M-S-Right>', "e", "Shift Selection Right By A Word")
map('v', '<M-S-Left>', "b", "Shift Selection Left By A Word")

map({ 'n', 'v' }, '<M-BS>', 'hvbd', "Delete Word Before Cursor")
map({ 'n', 'v' }, '<M-Del>', 'ved', "Delete Word After Cursor")
map('i', '<M-BS>', '<C-w>', "Delete Word Before Cursor")
map('i', '<M-Del>', '<Right><ESC>dei', "Delete Word After Cursor")

map('v', '<Tab>', ">gv", "Indent Selection")
map('v', '<S-Tab>', "<gv", "Unindent Selection")
map('v', '<BS>', 'd', "Delete Selection")
map('v', '<DEL>', 'd', "Delete Selection")

map('v', '<', "<Plug>(nvim-surround-visual)>", "Surround Selection With `<>`")
map('v', '(', "<Plug>(nvim-surround-visual))", "Surround Selection With `()`")
map('v', '[', "<Plug>(nvim-surround-visual)]", "Surround Selection With `[]`")
map('v', '{', "<Plug>(nvim-surround-visual)}", "Surround Selection With `{}`")
map('v', "'", "<Plug>(nvim-surround-visual)'", "Surround Selection With `''`")
map('v', '"', '<Plug>(nvim-surround-visual)"', 'Surround Selection With `""`')

local comment = function() return require('vim._comment').operator() .. '_' end
map({ 'i', 'n' }, '<M-/>', '<ESC>' .. comment(), "Toggle Comment", { expr = true })
map('v', '<M-/>', comment(), "Toggle Comment", { expr = true })

-- Copy/Cut/Paste/Undo/Redo
map(all_modes, '<M-v>', '<ESC>pa', "Paste")
map(all_modes, '<M-z>', '<ESC>ui', "Undo")
map(all_modes, '<M-S-z>', '<ESC><C-r>i', "Redo")

map({ 'i', 'n' }, '<M-x>', '<ESC>dd<ESC>i', "Cut")
map('v', '<M-x>', '"+d<ESC>i', "Cut")
map('v', '<M-c>', '"+y<ESC>i', "Copy")

-- LSP Bindings
map(all_modes, '<F2>', vim.lsp.buf.rename, "LSP Rename")
map(all_modes, '<M-.>', vim.lsp.buf.code_action, "LSP Code Action")
map(all_modes, '<M-C-k>', vim.lsp.buf.references, "LSP References")

map(all_modes, '<M-S-i>', function() vim.lsp.buf.format({ async = true }) end, "LSP Format")
map(all_modes, '<M-k>', function() vim.lsp.buf.hover({ border = 'rounded' }) end, "LSP Hover")
map(all_modes, '<C-k>', function() vim.lsp.buf.implementation({ reuse_win = true }) end, "LSP Implementation")

-- Diagnostics
map(all_modes, '<M-e>', vim.diagnostic.open_float, "Open Diagnostics")
