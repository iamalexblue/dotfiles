-- ==========================================================================
-- Lualine 状态栏配置 (Lualine Statusline)
-- ==========================================================================
-- Lualine 是 Neovim 的底部状态栏插件
-- Gruvbox 主题会自动为 lualine 设置配色，这里只需基本配置

return {
	"nvim-lualine/lualine.nvim",

	dependencies = {
		"nvim-tree/nvim-web-devicons", -- 文件图标支持
	},

	config = function()
		local lualine = require("lualine")
		local lazy_status = require("lazy.status") -- 显示插件更新数量

		-- 自定义日期时间组件
		local function datetime()
			return os.date(" %Y-%m-%d   %H:%M:%S")
		end

		-- Gruvbox 主题会自动应用，此处使用默认配置
		lualine.setup({
			sections = {
				-- 右侧区域：时间日期、插件更新、编码、文件格式、文件类型
				lualine_y = {
					{ datetime }, -- 日期时间显示
				},
				lualine_x = {
					-- 显示待更新的插件数量（仅当有更新时可见）
					{
						lazy_status.updates,
						cond = lazy_status.has_updates,
						color = { fg = "#fabd2f" }, -- Gruvbox 黄色
					},
					{ "encoding" }, -- 文件编码 (如 UTF-8)
					{
						"fileformat", -- 文件格式 (Unix/Linux)
						symbols = {
							unix = "", -- Unix 符号
						},
					},
					{ "filetype" }, -- 文件类型
				},
			},
		})
	end,
}
