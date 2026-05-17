-- ==========================================================================
-- LSP 键盘映射与诊断配置 (LSP Keymaps & Diagnostics)
-- ==========================================================================

local keymap = vim.keymap

-- 当 LSP 服务附加到缓冲区时自动执行的配置
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("UserLspConfig", {}),
  callback = function(ev)
    -- 获取当前缓冲区本地映射的选项
    local opts = { buffer = ev.buf, silent = true }

    -- =====================================================================
    -- 跳转类快捷键 (Navigation Keymaps)
    -- =====================================================================
    keymap.set("n", "gR", "<cmd>Telescope lsp_references<CR>", { buffer = ev.buf, silent = true, desc = "Show LSP references" })
    keymap.set("n", "gD", vim.lsp.buf.declaration, { buffer = ev.buf, silent = true, desc = "Go to declaration" })
    keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = ev.buf, silent = true, desc = "Show LSP definition" })
    keymap.set("n", "gi", "<cmd>Telescope lsp_implementations<CR>", { buffer = ev.buf, silent = true, desc = "Show LSP implementations" })
    keymap.set("n", "gt", "<cmd>Telescope lsp_type_definitions<CR>", { buffer = ev.buf, silent = true, desc = "Show LSP type definitions" })

    -- =====================================================================
    -- 代码操作快捷键 (Code Action Keymaps)
    -- =====================================================================
    -- 在可视模式下选择内容后触发代码操作
    keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, { buffer = ev.buf, silent = true, desc = "See available code actions" })
    -- 智能重命名（修改变量名会自动更新所有引用）
    keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { buffer = ev.buf, silent = true, desc = "Smart rename" })

    -- =====================================================================
    -- 诊断信息快捷键 (Diagnostics Keymaps)
    -- =====================================================================
    -- 显示当前 buffer 的所有诊断信息
    keymap.set("n", "<leader>D", "<cmd>Telescope diagnostics bufnr=0<CR>", { buffer = ev.buf, silent = true, desc = "Show buffer diagnostics" })
    -- 显示光标所在行的诊断信息
    keymap.set("n", "<leader>d", vim.diagnostic.open_float, { buffer = ev.buf, silent = true, desc = "Show line diagnostics" })
    -- 跳转到上一个/下一个诊断
    keymap.set("n", "[d", function()
      vim.diagnostic.jump({ count = -1, float = true })
    end, { buffer = ev.buf, silent = true, desc = "Go to previous diagnostic" })
    keymap.set("n", "]d", function()
      vim.diagnostic.jump({ count = 1, float = true })
    end, { buffer = ev.buf, silent = true, desc = "Go to next diagnostic" })

    -- =====================================================================
    -- 文档与信息快捷键 (Documentation Keymaps)
    -- =====================================================================
    -- 悬停显示光标处符号的文档（类型、定义等）
    keymap.set("n", "K", vim.lsp.buf.hover, { buffer = ev.buf, silent = true, desc = "Show documentation for what is under cursor" })

    -- =====================================================================
    -- LSP 控制快捷键 (LSP Control Keymaps)
    -- =====================================================================
    -- 重启 LSP（当 LSP 出现问题时使用）
    keymap.set("n", "<leader>rs", ":LspRestart<CR>", { buffer = ev.buf, silent = true, desc = "Restart LSP" })
  end,
})

-- ==========================================================================
-- 内联提示配置 (Inlay Hints)
-- ==========================================================================
-- 取消注释可开启变量类型内联显示
-- vim.lsp.inlay_hint.enable(true)

-- ==========================================================================
-- 诊断符号配置 (Diagnostic Signs)
-- ==========================================================================
-- 自定义诊断信息的图标（错误、警告、提示、信息）
local severity = vim.diagnostic.severity

vim.diagnostic.config({
  signs = {
    text = {
      [severity.ERROR] = " ",  -- 错误图标
      [severity.WARN] = " ",   -- 警告图标
      [severity.HINT] = "󰠠 ",  -- 提示图标
      [severity.INFO] = " ",  -- 信息图标
    },
  },
})
