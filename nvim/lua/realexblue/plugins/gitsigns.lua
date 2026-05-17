-- ==========================================================================
-- Git Signs 配置 (Git Signs)
-- ==========================================================================
-- 在行号栏显示 Git 变更（添加、修改、删除）
-- 并提供快速 staging/unstaging 等 Git 操作

return {
  "lewis6991/gitsigns.nvim",

  -- 提前加载，减少延迟感
  event = { "BufReadPre", "BufNewFile" },

  opts = {
    -- 当 Git Signs 附加到缓冲区时执行的配置
    on_attach = function(bufnr)
      local gs = package.loaded.gitsigns

      -- 封装 keymap.set，方便为不同模式设置按键
      local function map(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
      end

      -- =====================================================================
      -- 导航操作 (Navigation)
      -- =====================================================================
      map("n", "]h", gs.next_hunk, "Next Hunk")      -- 跳转到下一个变更块
      map("n", "[h", gs.prev_hunk, "Prev Hunk")      -- 跳转到上一个变更块

      -- =====================================================================
      -- Stage 操作 (Staging)
      -- =====================================================================
      -- Stage 单个 hunk（变更块）
      map("n", "<leader>hs", gs.stage_hunk, "Stage hunk")
      map("v", "<leader>hs", function()
        gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
      end, "Stage hunk")

      -- Reset 单个 hunk
      map("n", "<leader>hr", gs.reset_hunk, "Reset hunk")
      map("v", "<leader>hr", function()
        gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
      end, "Reset hunk")

      -- =====================================================================
      -- Buffer 级别操作 (Buffer Level)
      -- =====================================================================
      map("n", "<leader>hS", gs.stage_buffer, "Stage buffer")   -- Stage 整个文件
      map("n", "<leader>hR", gs.reset_buffer, "Reset buffer")   -- Reset 整个文件

      -- Undo上次 stage 的 hunk
      map("n", "<leader>hu", gs.undo_stage_hunk, "Undo stage hunk")

      -- =====================================================================
      -- 预览与 Blame (Preview & Blame)
      -- =====================================================================
      map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")    -- 预览当前 hunk 变更
      map("n", "<leader>hb", function()                          -- 显示当前行的 blame 信息
        gs.blame_line({ full = true })
      end, "Blame line")
      map("n", "<leader>hB", gs.toggle_current_line_blame, "Toggle line blame") -- 开关行 blame

      -- =====================================================================
      -- Diff 操作 (Diff)
      -- =====================================================================
      map("n", "<leader>hd", gs.diffthis, "Diff this")          -- 与 HEAD 对比当前文件
      map("n", "<leader>hD", function()                          -- 与上一个 commit 对比
        gs.diffthis("~")
      end, "Diff this ~")

      -- =====================================================================
      -- 文本对象 (Text Object)
      -- =====================================================================
      -- 在操作符模式 (operator-pending) 和可视模式下选择整个 hunk
      map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "Gitsigns select hunk")
    end,
  },
}
