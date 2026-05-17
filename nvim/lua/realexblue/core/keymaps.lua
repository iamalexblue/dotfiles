vim.g.mapleader = " "

local keymap = vim.keymap

-- ==========================================================================
-- 退出快捷键 (Exit Mode)
-- ==========================================================================
keymap.set("i", "jk", "<ESC>", { desc = "Exit insert mode with jk" })
keymap.set("c", "jk", "<C-c>", { desc = "Cancel command input" })
keymap.set("t", "jk", [[<C-\><C-n>]], { desc = "Escape terminal mode" })
keymap.set("v", "jk", "<ESC>", { desc = "Exit visual mode with jk" })

-- ==========================================================================
-- 撤销与重做 (Undo & Redo)
-- ==========================================================================
keymap.set("n", "u", "u", { desc = "Undo" })
keymap.set("n", "U", "<C-r>", { desc = "Redo" })

-- ==========================================================================
-- 光标位置 (Cursor Position)
-- ==========================================================================
-- gH 跳到绝对行首（第 0 列），gL 跳到绝对行末
-- 用 g 开头避免覆盖原生 H/L（屏幕首行/末行）
keymap.set({ "n", "v" }, "gH", "0", { desc = "Absolute line start" })
keymap.set({ "n", "v" }, "gL", "$", { desc = "Absolute line end" })

-- ==========================================================================
-- 搜索高亮 (Search Highlight)
-- ==========================================================================
keymap.set("n", "<leader>nh", ":nohl<CR>", { desc = "Clear search highlights" })

-- ==========================================================================
-- 翻页快捷键 (Scroll Navigation)
-- ==========================================================================
-- <leader>j/k 实现半页翻动，比 Ctrl 更近更快
keymap.set({ "n", "v" }, "<leader>j", "<C-d>", { desc = "Scroll down half page" })
keymap.set({ "n", "v" }, "<leader>k", "<C-u>", { desc = "Scroll up half page" })

-- ==========================================================================
-- 数字增减 (Number Increment/Decrement)
-- ==========================================================================
keymap.set("n", "<leader>+", "<C-a>", { desc = "Increment number" })
keymap.set("n", "<leader>-", "<C-x>", { desc = "Decrement number" })

-- ==========================================================================
-- 窗口穿梭 (Window Navigation)
-- ==========================================================================
-- Ctrl + h/j/k/l 在窗口间快速跳转
local win_opts = { noremap = true, silent = true }
keymap.set("n", "<C-h>", "<C-w>h", win_opts)
keymap.set("n", "<C-j>", "<C-w>j", win_opts)
keymap.set("n", "<C-k>", "<C-w>k", win_opts)
keymap.set("n", "<C-l>", "<C-w>l", win_opts)

-- ==========================================================================
-- 分屏操作 (Split Window)
-- ==========================================================================
keymap.set("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" })
keymap.set("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" })
keymap.set("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" })
keymap.set("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" })

-- ==========================================================================
-- 标签页操作 (Tab Management)
-- ==========================================================================
keymap.set("n", "<leader>to", "<cmd>tabnew<CR>", { desc = "Open new tab" })
keymap.set("n", "<leader>tx", "<cmd>tabclose<CR>", { desc = "Close current tab" })
keymap.set("n", "<leader>tn", "<cmd>tabn<CR>", { desc = "Go to next tab" })
keymap.set("n", "<leader>tp", "<cmd>tabp<CR>", { desc = "Go to previous tab" })
keymap.set("n", "<leader>tf", "<cmd>tabnew %<CR>", { desc = "Open current buffer in new tab" })

-- ==========================================================================
-- 终端内窗口跳转 (Terminal Window Navigation)
-- ==========================================================================
-- 在终端里按 jkk 再按 k 跳到上方窗口，以此类推
keymap.set("t", "jkk", [[<C-\><C-n><C-w>k]], win_opts)
keymap.set("t", "jkj", [[<C-\><C-n><C-w>j]], win_opts)
keymap.set("t", "jkh", [[<C-\><C-n><C-w>h]], win_opts)
keymap.set("t", "jkl", [[<C-\><C-n><C-w>l]], win_opts)

-- ==========================================================================
-- 常用功能 (Common Features)
-- ==========================================================================
keymap.set("n", "<leader>o", "<cmd>SymbolsOutline<CR>", { desc = "Toggle code outline" })
keymap.set("n", "<leader>u", vim.cmd.UndotreeToggle, { desc = "Toggle undo tree" })
keymap.set("n", "<leader>t", ":split | term<CR>", { desc = "Open terminal below" })

-- ==========================================================================
-- 文件树快捷键 (File Explorer)
-- ==========================================================================
-- 将文件树快捷键移到核心配置中，确保启动时立即生效
keymap.set("n", "<leader>ee", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle file explorer" })
keymap.set("n", "<leader>ef", "<cmd>NvimTreeFindFileToggle<CR>", { desc = "Toggle file explorer on current file" })
keymap.set("n", "<leader>ec", "<cmd>NvimTreeCollapse<CR>", { desc = "Collapse file explorer" })
keymap.set("n", "<leader>er", "<cmd>NvimTreeRefresh<CR>", { desc = "Refresh file explorer" })

-- ==========================================================================
-- 导航快捷键 (Navigation)
-- ==========================================================================
-- gh: Go Home - 一键回到启动页 (Alpha)
keymap.set("n", "gh", "<cmd>Alpha<CR>", { desc = "Go to home (Alpha dashboard)" })

-- ==========================================================================
-- 热重载配置 (Hot Reload Config)
-- ==========================================================================
keymap.set("n", "<leader>s", function()
	vim.cmd("source $MYVIMRC")
	vim.notify("Config reloaded!", vim.log.levels.INFO)
end, { desc = "Reload config" })

-- ==========================================================================
-- 平滑滚动 (Smooth Scroll)
-- ==========================================================================
-- 鼠标滚轮实现丝滑翻页，光标纹丝不动
local scroll_opts = { silent = true }
keymap.set("n", "<ScrollWheelUp>", "<C-y>", scroll_opts)
keymap.set("n", "<ScrollWheelDown>", "<C-e>", scroll_opts)
keymap.set("i", "<ScrollWheelUp>", "<C-o><C-y>", scroll_opts)
keymap.set("i", "<ScrollWheelDown>", "<C-o><C-e>", scroll_opts)
keymap.set("v", "<ScrollWheelUp>", "<C-y>", scroll_opts)
keymap.set("v", "<ScrollWheelDown>", "<C-e>", scroll_opts)

-- ==========================================================================
-- 空格快捷键 (Space Key)
-- ==========================================================================
-- 空格在普通/可视模式下开启命令行
keymap.set({ "n", "v" }, "<Space>", ":", { desc = "Space opens command mode" })
