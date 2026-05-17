-- ==========================================================================
-- Telescope 文件搜索配置 (Telescope Fuzzy Finder)
-- ==========================================================================
-- Telescope 是 Neovim 最强大的模糊搜索插件
-- 支持文件搜索、内容搜索、快捷键搜索等

return {
  "nvim-telescope/telescope.nvim",
  version = "*",

  dependencies = {
    "nvim-lua/plenary.nvim",                           -- 基础 Lua 函数库
    { "nvim-telescope/telescope-fzf-native.nvim",      -- FZF 搜索算法加速
      build = "make"
    },
    "nvim-tree/nvim-web-devicons",                      -- 文件图标支持
    "folke/todo-comments.nvim",                         -- TODO 注释搜索
    "benfowler/telescope-luasnip.nvim",                -- LuaSnip 代码片段搜索
  },

  config = function()
    local telescope = require("telescope")
    local actions = require("telescope.actions")
    local transform_mod = require("telescope.actions.mt").transform_mod

    local trouble = require("trouble")
    local trouble_telescope = require("trouble.sources.telescope")

    -- =====================================================================
    -- 自定义动作 (Custom Actions)
    -- =====================================================================
    -- 将选中的搜索结果发送到 Trouble Quickfix 列表
    local custom_actions = transform_mod({
      open_trouble_qflist = function(prompt_bufnr)
        trouble.toggle("quickfix")
      end,
    })

    -- =====================================================================
    -- Telescope 基础配置 (Basic Configuration)
    -- =====================================================================
    telescope.setup({
      defaults = {
        -- 路径显示为智能格式（缩写路径）
        path_display = { "smart" },

        -- =================================================================
        -- 插入模式按键映射 (Insert Mode Mappings)
        -- =================================================================
        mappings = {
          i = {
            -- 上下移动选择项（之前是 Ctrl+j/k，改为 Ctrl+n/p 避免冲突）
            ["<C-p>"] = actions.move_selection_previous,
            ["<C-n>"] = actions.move_selection_next,
            -- 发送到 quickfix 并在 Trouble 中打开
            ["<C-q>"] = actions.send_selected_to_qflist + custom_actions.open_trouble_qflist,
            -- 在 Trouble 中打开
            ["<C-t>"] = trouble_telescope.open,
          },
        },
      },
    })

    -- 加载扩展
    telescope.load_extension("fzf")      -- FZF 算法加速
    telescope.load_extension("luasnip")   -- 代码片段搜索

    -- =====================================================================
    -- 快捷键绑定 (Keybindings)
    -- =====================================================================
    local keymap = vim.keymap

    keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>",        { desc = "Fuzzy find files in cwd" })
    keymap.set("n", "<leader>fr", "<cmd>Telescope oldfiles<cr>",         { desc = "Fuzzy find recent files" })
    keymap.set("n", "<leader>fs", "<cmd>Telescope live_grep<cr>",        { desc = "Find string in cwd" })
    keymap.set("n", "<leader>fc", "<cmd>Telescope grep_string<cr>",      { desc = "Find string under cursor in cwd" })
    keymap.set("n", "<leader>ft", "<cmd>TodoTelescope<cr>",             { desc = "Find todos" })
    keymap.set("n", "<leader>fk", "<cmd>Telescope keymaps<cr>",          { desc = "Find keymaps" })
  end,
}
