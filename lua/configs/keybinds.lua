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
local all = { 'v', 'i', 'n' }

-- Core Telescope and File Navigation
map(all, '<C-b>', "<CMD>NvimTreeToggle<CR>", "Toggle File Tree")
map(all, '<C-g>', "<CMD>FloatermNew --title=Git --height=0.9 --width=0.8 lazygit<CR>", "Open LazyGit")
map(all, '<C-,>', "<CMD>FloatermNew --title=Config --height=0.9 --width=0.8 nvim ~/.config/nvim<CR>", "Open Nvim Config")
map(all, '<M-p>', "<CMD>Telescope find_files<CR>", "Telescope: Find Files (file palette)")
map(all, '<M-S-p>', "<CMD>Telescope commands<CR>", "Telescope: Commands (command palette)")
map(all, '<M-S-]>', "<CMD>BufferLineCycleNext<CR>", "Cycle Next Buffer")
map(all, '<M-S-[>', "<CMD>BufferLineCyclePrev<CR>", "Cycle Previous Buffer")

-- Visual Multi
vim.g.VM_default_mappings = 0
map(all, '<M-S-d>', '<ESC><Plug>(VM-Select-All)', "VM: Select All Occurrences")
map(all, '<C-S-Up>', '<ESC><Plug>(VM-Select-Cursor-Up)', "VM: Start Selecting Up")
map(all, '<C-S-Down>', '<ESC><Plug>(VM-Select-Cursor-Down)', "VM: Start Selecting Down")
map({ 'i', 'n' }, '<M-d>', '<ESC><Plug>(VM-Find-Under)', "VM: Select Next Word Down")
map('v', '<M-d>', '<Plug>(VM-Find-Subword-Under)', "VM: Select Next Word Down")

-- Split Panes
vim.o.spr = true
vim.o.sb = true
map(all, '<M-\\>', '<CMD>vsplit<CR>', "Vertical Split")
map(all, '<M-->', '<CMD>split<CR>', "Horizontal Split")
map(all, '<M-S-\\>', "<CMD>vsplit <BAR> terminal<CR>i", "Terminal in Vertical Split")
map(all, '<M-S-->', "<CMD>split <BAR> terminal<CR>i", "Terminal in Horizontal Split")
map(all, '<C-Left>', "<ESC><C-w>h", "Move Between Splits Left")
map(all, '<C-Down>', "<ESC><C-w>j", "Move Between Splits Down")
map(all, '<C-Up>', "<ESC><C-w>k", "Move Between Splits Up")
map(all, '<C-Right>', "<ESC><C-w>l", "Move Between Splits Right")

-- Quit, Write, Search
map(all, '<M-q>', "<CMD>qa<CR>", "Quit All")
map(all, '<M-S-w>', "<CMD>q<CR>", "Close Window")
map(all, '<M-w>', "<CMD>bp <BAR> bd #<CR>", "Close Tab")
map(all, '<M-s>', "<CMD>w<CR>", "Write File")
map(all, '<M-S-f>', "<CMD>Telescope live_grep<CR>", "Search All Files")

-- Select All, Move Lines, Selection Manipulation
map(all, '<M-a>', "<ESC>ggVG", "Select All")

map({ 'i', 'n' }, '<M-C-S-Up>', '<ESC>yyP', "Duplicate Line Up")
map({ 'i', 'n' }, '<M-C-S-Down>', '<ESC>yyp', "Duplicate Line Down")
map('v', '<M-C-S-Up>', ":t '>+0<CR>gv=gv", "Duplicate Selection Up")
map('v', '<M-C-S-Down>', ":t '<-1<CR>gv=gv", "Duplicate Selection Down")

map({ 'i', 'n' }, '<M-Up>', '<CMD>m .-2<CR>', "Move Line Up")
map({ 'i', 'n' }, '<M-Down>', '<CMD>m .+1<CR>', "Move Line Down")
map('v', '<M-Up>', ":m '<-2<CR>gv=gv", "Move Selection Up")
map('v', '<M-Down>', ":m '>+1<CR>gv=gv", "Move Selection Down")

map({ 'i', 'n' }, '<M-Right>', "<ESC>ea", "Move To Next Word")
map({ 'i', 'n' }, '<M-Left>', "<ESC>bi", "Move To Previous Word")
map('v', '<M-S-Right>', "e", "Shift Selection Right By A Word")
map('v', '<M-S-Left>', "b", "Shift Selection Left By A Word")

map({ 'v', 'n' }, '<M-BS>', 'hvbd', "Delete Word Before Cursor")
map({ 'v', 'n' }, '<M-Del>', 'ved', "Delete Word After Cursor")
map('i', '<M-BS>', '<C-w>', "Delete Word Before Cursor")
map('i', '<M-Del>', '<Right><ESC>dei', "Delete Word After Cursor")

map({ 'v', 'n' }, '<Tab>', ">gv", "Indent Selection")
map({ 'v', 'n' }, '<S-Tab>', "<gv", "Unindent Selection")
map('v', '<BS>', '"_d', "Delete Selection")
map('v', '<DEL>', '"_d', "Delete Selection")

local surround_keys = { "()", "[]", "{}", "''", '""', "``" }
for _, key in ipairs(surround_keys) do
    local open, close = key:sub(1, 1), key:sub(2, 2)
    map('v', open, "<Plug>(nvim-surround-visual)" .. close, "Surround Selection With `" .. key .. "`")
end

local comment = function() return require('vim._comment').operator() .. '_' end
map({ 'i', 'n' }, '<M-/>', '<ESC>' .. comment(), "Toggle Comment", { expr = true })
map('v', '<M-/>', comment(), "Toggle Comment", { expr = true })

-- Copy/Cut/Paste/Undo/Redo
map({ 'i', 'n' }, '<M-v>', '<ESC>"+pa', "Paste")
map('v', '<M-v>', '"+pa', "Paste")

map(all, '<M-z>', '<ESC>ui', "Undo")
map(all, '<M-S-z>', '<ESC><C-r>i', "Redo")

map({ 'i', 'n' }, '<M-x>', '<ESC>dd<ESC>i', "Cut")
map('v', '<M-x>', '"+d<ESC>i', "Cut")
map('v', '<M-c>', '"+y<ESC>i', "Copy")

-- LSP Bindings
map(all, '<F2>', vim.lsp.buf.rename, "LSP Rename")
map(all, '<M-.>', vim.lsp.buf.code_action, "LSP Code Action")
map(all, '<M-C-k>', vim.lsp.buf.references, "LSP References")

map(all, '<M-S-i>', function() vim.lsp.buf.format({ async = true }) end, "LSP Format")
map(all, '<M-k>', function() vim.lsp.buf.hover({ border = 'rounded' }) end, "LSP Hover")
map(all, '<C-k>', function() vim.lsp.buf.implementation({ reuse_win = true }) end, "LSP Implementation")

-- Diagnostics
map(all, '<M-e>', vim.diagnostic.open_float, "Open Diagnostics")
