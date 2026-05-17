-- ==========================================================================
-- 基础依赖插件列表 (Base Dependency Plugins)
-- ==========================================================================
-- 这些是其他插件依赖的基础库，不单独提供功能

return {
  -- Lua 函数库，为很多插件提供通用的 Lua 函数
  "nvim-lua/plenary.nvim",

  -- Tmux 与 Neovim 分屏窗口导航集成
  -- 可以在 Neovim 分屏和 tmux pane 之间无缝切换
  "christoomey/vim-tmux-navigator",

  -- ==========================================================================
  -- 代码大纲与撤销树 (Code Outline & Undo Tree)
  -- ==========================================================================

  -- 代码大纲 - 显示符号（函数、变量、类）的侧边栏面板
  {
    "simrat39/symbols-outline.nvim",
    config = function()
      require("symbols-outline").setup({
        position = "right",   -- 显示在右侧
        width = 25,           -- 宽度
        auto_preview = false, -- 禁用自动预览
      })
    end,
  },

  -- 可视化撤销树 - 以树状图展示代码修改历史
  "mbbill/undotree",
}
