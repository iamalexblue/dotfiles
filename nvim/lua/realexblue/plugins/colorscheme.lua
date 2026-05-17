-- ==========================================================================
-- 颜色主题配置 (Color Scheme)
-- ==========================================================================
-- 当前使用：Gruvbox Dark（高对比度版本）
-- 对比度可选："hard"（更高）或 "harder"（最高）

return {
  {
    "ellisonleao/gruvbox.nvim",
    priority = 1000,  -- 确保优先加载

    config = function()
      require("gruvbox").setup({
        -- 对比度设置："hard" 或 "harder" 获得更高对比度
        contrast = "hard",

        -- 强制使用深色模式
        dark_mode = true,
      })

      -- 应用主题
      vim.cmd("colorscheme gruvbox")
    end,
  },
}
