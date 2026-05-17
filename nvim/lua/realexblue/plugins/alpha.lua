-- ==========================================================================
-- Alpha 启动页面配置 (Alpha Start Screen)
-- ==========================================================================
-- Alpha 是 Neovim 的启动画面插件，显示欢迎信息和快捷操作

return {
  "goolord/alpha-nvim",
  event = "VimEnter",  -- 在 Neovim 启动后立即显示

  config = function()
    local alpha = require("alpha")
    local dashboard = require("alpha.themes.dashboard")

    -- =====================================================================
    -- ASCII 艺术标题 (ASCII Art Header)
    -- =====================================================================
    dashboard.section.header.val = {
      "                                                     ",
      "  ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗ ",
      "  ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║ ",
      "  ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║ ",
      "  ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║ ",
      "  ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║ ",
      "  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝ ",
      "                                                     ",
    }

    -- =====================================================================
    -- 快捷按钮配置 (Quick Action Buttons)
    -- =====================================================================
    dashboard.section.buttons.val = {
      -- 新建文件
      dashboard.button("e", "  > New File", "<cmd>ene<CR>"),
      -- 切换文件浏览器
      dashboard.button("SPC ee", "  > Toggle file explorer", "<cmd>NvimTreeToggle<CR>"),
      -- 查找文件
      dashboard.button("SPC ff", "󰱼 > Find File", "<cmd>Telescope find_files<CR>"),
      -- 搜索字符串
      dashboard.button("SPC fs", "  > Find Word", "<cmd>Telescope live_grep<CR>"),
      -- 恢复会话
      dashboard.button("SPC wr", "󰁯  > Restore Session For Current Directory", "<cmd>AutoSession restore<CR>"),
      -- 退出 Neovim
      dashboard.button("q", " > Quit NVIM", "<cmd>qa<CR>"),
    }

    -- 应用配置
    alpha.setup(dashboard.opts)

    -- =====================================================================
    -- 禁用折叠 (Disable Folding)
    -- =====================================================================
    -- Alpha 页面不需要折叠功能，禁用它
    vim.cmd([[autocmd FileType alpha setlocal nofoldenable]])
  end,
}
