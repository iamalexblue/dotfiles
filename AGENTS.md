# dotfiles 仓库说明（Agent 记忆）

本仓库 = 用户的跨设备配置文件集（Gruvbox 主题全桶）。

- 远端：`git@github.com:iamalexblue/dotfiles.git`（分支 `main`）
- 本仓库同时放置 `AGENTS.md` 与 `CLAUDE.md`，内容一致，分别供 opencode / Claude Code 读取。

## 仓库结构

```
powershell/
├── Microsoft.PowerShell_profile.ps1   # $PROFILE（UTF-8 BOM）
└── scripts/                           # 独立脚本（小写 scripts\）
    ├── mac-mini.ps1                   # smac/wmac Mac mini 显示器控制
    └── Add-StartMenuShortcuts.ps1     # sm-update 开始菜单快捷方式同步
nvim/  rime/  starship/  zshconfig/  'kitty config/'
```

## 同步流程（触发词：「把配置文件同步一下」「同步 dotfiles」「更新仓库内容」）

- **以本地为准，覆盖到仓库**，不要反过来问。
- PowerShell：
  1. 本地 profile 实际路径：`C:\Users\reale\OneDrive\文档\PowerShell\Microsoft.PowerShell_profile.ps1`
  2. `Copy-Item $PROFILE powershell/Microsoft.PowerShell_profile.ps1 -Force`
  3. 复制本地 `scripts\*.ps1` 到 `powershell/scripts/`
  4. PSParser 校验语法通过
  5. 有功能新增时更新 README（结构树 + PowerShell 小节）
  6. commit（conventional commits）+ push 到 `origin main`
- **编码铁律**：本地 profile 是 UTF-8 BOM。用 `Copy-Item` 保字节复制；**绝不用写工具/编辑器重写**（会把 UTF-8 中文损坏成 GBK 乱码 / PUA 字符，历史教训）。
- git 不在 PATH：用 `C:\Users\reale\AppData\Local\Fork\gitInstance\2.50.1\cmd\git.exe`
- 详细流程见全局内存（`~/.config/opencode/AGENTS.md` 与 `~/.claude/CLAUDE.md`）。
