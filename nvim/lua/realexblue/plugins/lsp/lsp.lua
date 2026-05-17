-- ==========================================================================
-- CMP LSP 补全配置 (CMP LSP Completion)
-- ==========================================================================
-- nvim-cmp 是 Neovim 的自动补全引擎
-- 此文件配置 LSP 补全源，为代码补全提供 LSP 语义信息

return {
  -- CMP LSP 补全源 - 连接 LSP 和 nvim-cmp
  "hrsh7th/cmp-nvim-lsp",

  -- 在读取文件前就加载，确保补全可用
  event = { "BufReadPre", "BufNewFile" },

  dependencies = {
    -- 文件操作增强 - LSP 重命名/移动文件时自动更新引用
    { "antosha417/nvim-lsp-file-operations", config = true },

    -- Lazy.dev - 为 lazy.nvim 插件提供 Lua  LSP 支持
    { "folke/lazydev.nvim", opts = {} },
  },

  config = function()
    -- 导入 CMP LSP 插件
    local cmp_nvim_lsp = require("cmp_nvim_lsp")

    -- 获取 LSP 默认能力配置（包含补全能力）
    -- 这个配置会被赋值给所有 LSP 服务器
    local capabilities = cmp_nvim_lsp.default_capabilities()

    -- 为所有 LSP 服务器配置统一的补全能力
    vim.lsp.config("*", {
      capabilities = capabilities,
    })
  end,
}
