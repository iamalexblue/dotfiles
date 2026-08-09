<div align="center">

```
██████╗  ██████╗ ████████╗███████╗██╗     ██╗     ███████╗
██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝██║     ██║     ██╔════╝
██║  ██║██║   ██║   ██║   █████╗  ██║     ██║     █████╗
██║  ██║██║   ██║   ██║   ██╔══╝  ██║     ██║     ██╔══╝
██████╔╝╚██████╔╝   ██║   ██║     ███████╗███████╗███████╗
╚═════╝  ╚═════╝    ╚═╝   ╚═╝     ╚══════╝╚══════╝╚══════╝
```

# dotfile

**个人开发环境配置文件集 · Gruvbox 主题全家桶**

一套配置，统一五端：终端、编辑器、输入法、Shell、提示符。

[![editor](https://img.shields.io/badge/editor-neovim-98971A?style=flat-square&logo=neovim&logoColor=EBDBB2)](https://neovim.io)
[![terminal](https://img.shields.io/badge/terminal-kitty-458588?style=flat-square&logo=kitty&logoColor=EBDBB2)](https://sw.kovidgoyal.net/kitty/)
[![shell](https://img.shields.io/badge/shell-zsh-FE8019?style=flat-square&logo=gnubash&logoColor=EBDBB2)](https://www.zsh.org)
[![powershell](https://img.shields.io/badge/powershell-458588?style=flat-square&logo=powershell&logoColor=EBDBB2)](https://github.com/PowerShell/PowerShell)
[![prompt](https://img.shields.io/badge/prompt-starship-FB4934?style=flat-square&logo=starship&logoColor=EBDBB2)](https://starship.rs)
[![ime](https://img.shields.io/badge/ime-rime-B16286?style=flat-square)](https://rime.im)
[![theme](https://img.shields.io/badge/theme-gruvbox-CC241D?style=flat-square)](https://github.com/morhetz/gruvbox)
[![manager](https://img.shields.io/badge/manager-lazy.nvim-D79921?style=flat-square)](https://github.com/folke/lazy.nvim)
[![platform](https://img.shields.io/badge/platform-win%20%7C%20macOS%20%7C%20linux-928374?style=flat-square)]()

</div>

---

## ✨ 特性

- 🎨 **全链路 Gruvbox** —— 终端、编辑器配色高度统一，深色护眼
- 📝 **Neovim 深度定制** —— lazy.nvim 管理 40+ 插件，模块化 `lua/realexblue/` 目录结构
- 🀄 **Rime 万象输入法** —— 小鹤双拼 + 模糊音 + 自定义翻页键位
- 🚀 **Starship 提示符** —— Gruvbox 调色板 Powerline 风格，多语言版本一目了然
- 🖥️ **PowerShell 增强** —— 代理一键开关、Hermes 快捷启动、Mac mini 显示控制
- 🐱 **Kitty 终端** —— Gruvbox Material Dark Medium 主题，配色精细调校
- 💻 **Zsh + Oh My Zsh** —— eastwood 主题，开箱即用的现代 Shell
- 🔄 **随时同步** —— 配置改动即时回收到仓库，多设备保持一致

## 📦 项目结构

```
dotfile/
├── kitty config/          # Kitty 终端模拟器配置
│   ├── kitty.conf             # 主配置
│   ├── current-theme.conf     # Gruvbox Material Dark Medium 主题
│   ├── dark-theme.auto.conf   # 自动深色主题
│   └── colors.conf            # Gruvbox Dark 基础配色 (Gogh)
├── nvim/                  # Neovim 配置
│   ├── init.lua               # 入口
│   ├── lazy-lock.json         # 插件版本锁
│   ├── after/                 # LSP 扩展 (emmet / graphql / svelte)
│   └── lua/realexblue/        # 模块化配置
│       ├── core/              # 核心设置、快捷键、选项
│       ├── lazy.lua           # lazy.nvim 引导
│       ├── lsp.lua            # LSP 入口
│       └── plugins/           # 按功能拆分的插件配置
├── rime/                  # Rime 输入法配置
│   └── wanxiang/              # 万象方案自定义 (小鹤双拼)
├── starship/             # Starship 提示符配置
│   └── starship.toml         # Gruvbox Powerline 风格
├── powershell/           # PowerShell 配置
│   ├── Microsoft.PowerShell_profile.ps1   # $PROFILE
│   └── scripts/              # 独立脚本
│       ├── mac-mini.ps1         # Mac mini 显示器控制（smac/wmac）
│       └── Add-StartMenuShortcuts.ps1    # 开始菜单快捷方式同步（sm-update）
├── zshconfig/             # Zsh 配置
│   └── .zshrc                 # Oh My Zsh
└── README.md              # 就是这个文件
```

## 🔧 组件详情

### 📝 Neovim — `nvim/`

基于 **lazy.nvim** 的模块化配置，每个插件一个文件，职责清晰、易于维护。

| 类别 | 插件 |
|------|------|
| 🚀 启动页 | `alpha-nvim`（自定义 ASCII 艺术标题） |
| 🎨 主题 | `gruvbox.nvim`（hard 对比度 · 强制深色） |
| 🧩 补全 | `nvim-cmp` + `mason` + 完整 LSP（emmet / graphql / svelte） |
| 🔍 搜索 | `telescope` · `todo-comments` |
| 🗂️ UI | `bufferline` · `lualine` · `nvim-tree` · `dressing` · `which-key` · `indent-blankline` · `trouble` |
| ✍️ 编辑 | `autopairs` · `surround` · `substitute` · `nvim-ts-autotag` · `vim-maximizer` · `flash` |
| 🌳 语法 | `treesitter` + `text-objects` |
| 🧹 质量 | `formatting` · `linting` |
| 🔀 Git | `gitsigns` · `lazygit` |
| 📈 效率 | `auto-session` · `undotree` · `symbols-outline` |
| ⏱️ 追踪 | `wakatime`（自动时间统计） |
| 🤖 AI | ChatGPT.nvim（预留，1Password 密钥管理） |

### 🐱 Kitty — `kitty config/`

- **Gruvbox Material Dark Medium** 主题（Sainnhe Park）
- Gogh 生成的 Gruvbox Dark 基础色板，深色背景 `#282828` / 前景 `#EBDBB2`
- 支持自动深色主题切换（`dark-theme.auto.conf`）

### 🀄 Rime — `rime/wanxiang/`

- **万象方案**自定义补丁（`wanxiang.custom.yaml`）
- 双拼布局：**小鹤双拼**（可切换自然码 / 搜狗 / 微软等 11 种方案）
- 模糊音：仅启用 `en-eng` / `in-ing`
- 自定义键位：`-` `=` `,` `.` `;` `'` `【` `】` 翻页，`Ctrl+Shift+3/4` 切换中英文标点与简繁

### 💻 Zsh — `zshconfig/`

- Oh My Zsh + `eastwood` 主题
- 中文注释的模块化配置：路径、补全、历史、别名

### 🚀 Starship — `starship/`

- **Gruvbox 调色板** Powerline 风格提示符（`palette = 'gruvbox_dark'`）
- 分段式布局：OS → 用户 → 目录 → Git → 语言版本（C/C++/Rust/Go/Node/Bun/PHP/Java/Kotlin/Haskell/Python）→ Docker/Conda → 时间
- 常用目录图标替换（Documents / Downloads / Developer…）、Vim 模式字符提示

### 🖥️ PowerShell — `powershell/`

- `pon` / `poff` —— mihomo 代理一键开关
- `hermes` / `hermesd`（`hd`）—— Hermes Agent 后台守护 + Web UI 启动
- `smac` / `wmac` 系列 —— Mac mini 显示器休眠/唤醒 + deskflow 客户端重启
- `scripts/mac-mini.ps1` —— smac/wmac 的独立脚本版（`.\mac-mini.ps1 wmac-full`，函数保留在 profile 中）
- `sm-update` —— 开始菜单快捷方式同步（`scripts/Add-StartMenuShortcuts.ps1`）：为 PowerToys CmdPal / Win 搜索补齐没有快捷方式的应用
  
  ```powershell
  sm-update                 # 扫描注册表 Uninstall + 便携目录，补建快捷方式
  sm-update -CleanVersion   # 去掉应用名里的版本号
  sm-update -Prune          # 清理失效快捷方式
  sm-update -Refresh        # 刷新 target 变化/失效的快捷方式
  sm-update -WhatIf         # 演练模式（先预览）
  sm-update -Help           # 查看完整用法
  ```
  
  > 安全：脚本只【读】注册表 Uninstall 项，从不写注册表；全部改动仅在开始菜单文件夹。运行后用 `sm-update -Prune -WhatIf` 预览，再重启 explorer + PowerToys 刷新 CmdPal 索引。

## 🚀 快速开始

> 仓库不含自动安装脚本，各组件按需复制/软链接到对应位置即可。

```bash
git clone git@github.com:iamalexblue/dotfiles.git ~/.dotfiles
```

| 组件 | Windows | macOS / Linux |
|------|---------|---------------|
| Neovim | `%LOCALAPPDATA%\nvim` | `~/.config/nvim` |
| Kitty | `%APPDATA%\kitty` | `~/.config/kitty` |
| Starship | `%USERPROFILE%\.config\starship.toml` | `~/.config/starship.toml` |
| PowerShell | `$PROFILE`（OneDrive\文档\WindowsPowerShell） | `~/.config/powershell/` |
| Rime | `%APPDATA%\Rime` | `~/Library/Rime` · `~/.config/ibus/rime` |
| Zsh | （WSL/MSYS 下）`~/.zshrc` | `~/.zshrc` |

## 🔄 维护与同步

改完本机配置后，同步回仓库：

```bash
# 以 Neovim 为例
cp -r "$LOCALAPPDATA/nvim/." nvim/     # Windows
cp -r ~/.config/nvim/. nvim/           # macOS / Linux

git add -A && git commit -m "chore(nvim): sync config" && git push
```

```powershell
# PowerShell：以本地 profile 为准，同步到仓库
$localProf = $PROFILE
$repoProf  = "D:\Dev\Fork\dotfiles\powershell\Microsoft.PowerShell_profile.ps1"
Copy-Item $localProf $repoProf -Force                                    # 覆盖仓库 profile
Copy-Item (Join-Path (Split-Path $PROFILE) "scripts\*.ps1") "D:\Dev\Fork\dotfiles\powershell\scripts\" -Force  # 同步独立脚本
git -C "D:\Dev\Fork\dotfiles" add -A
git -C "D:\Dev\Fork\dotfiles" commit -m "feat(powershell): sync profile"
git -C "D:\Dev\Fork\dotfiles" push origin main
```

> 注意：仓库以**本地 profile 为准**做同步；新增脚本统一放进 `powershell/scripts/`，并在 README 的 PowerShell 小节补一行说明。

## 🙏 致谢

- [Gruvbox](https://github.com/morhetz/gruvbox) — 贯穿全套配置的经典配色
- [lazy.nvim](https://github.com/folke/lazy.nvim) — Neovim 插件管理
- [dev-environment-files](https://github.com/josean-dev/dev-environment-files) — Neovim 配置的灵感来源，本仓库的 `lua/realexblue/` 即在其基础上按个人习惯定制
- [WakaTime](https://wakatime.com) — 编程时间追踪
