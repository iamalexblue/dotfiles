-- ==========================================================================
-- Mason LSP 工具安装器配置 (Mason LSP & Tool Installer)
-- ==========================================================================
-- Mason 是 LSP 服务器、格式化器、Linter 的安装管理工具
-- 此配置定义自动安装的语言服务器和工具列表

return {
  -- ==========================================================================
  -- Mason LSP Config - LSP 服务器管理器
  -- ==========================================================================
  {
    "williamboman/mason-lspconfig.nvim",

    opts = {
      -- 自动安装的 LSP 服务器列表
      ensure_installed = {
        -- Web 开发
        "ts_ls",       -- TypeScript/JavaScript
        "html",         -- HTML
        "cssls",        -- CSS
        "tailwindcss",  -- Tailwind CSS
        "svelte",       -- Svelte

        -- 后端/其他
        "lua_ls",       -- Lua (Neovim 配置开发)
        "graphql",      -- GraphQL
        "emmet_ls",     -- Emmet (HTML/CSS 缩写展开)
        "prismals",     -- Prisma (数据库 ORM)
        "pyright",      -- Python

        -- 注意：ESLint 通常通过 nvim-lint 或 Conform 集成，这里注释掉
        -- "eslint",
      },
    },

    dependencies = {
      -- Mason 核心本体
      {
        "williamboman/mason.nvim",

        opts = {
          -- UI 图标配置
          ui = {
            icons = {
              package_installed = "✓",     -- 已安装
              package_pending = "➜",       -- 安装中
              package_uninstalled = "✗",   -- 未安装
            },
          },
        },
      },

      -- Neovim 内置 LSP 配置库
      "neovim/nvim-lspconfig",
    },
  },

  -- ==========================================================================
  -- Mason Tool Installer - 代码格式化与 Lint 工具
  -- ==========================================================================
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",

    opts = {
      -- 自动安装的工具列表
      ensure_installed = {
        -- 格式化工具 (Formatter)
        "prettier",   -- Web 语言通用格式化 (JS/TS/CSS/HTML/JSON...)
        "stylua",    -- Lua 格式化工具
        "isort",     -- Python import 排序
        "black",     -- Python 代码格式化

        -- Linter
        "pylint",    -- Python Linter
        "eslint_d",  -- ESLint (后台进程版，更快)
      },
    },

    dependencies = {
      -- 依赖 Mason 核心
      "williamboman/mason.nvim",
    },
  },
}
