# dotfiles 仓库说明（Agent 记忆）

本仓库 = 用户的跨设备配置文件集（Gruvbox 主题全桶）。本文件与 `AGENTS.md` 内容一致（位于 `agents/` 目录），供 Claude Code 读取。

- 远端：`git@github.com:iamalexblue/dotfiles.git`（分支 `main`）

## 仓库结构

```
agents/
├── AGENTS.md                       # opencode 项目记忆（与本文内容一致）
├── CLAUDE.md                       # Claude Code 项目记忆（本文件）
└── skills/
    └── blog-style-alex/SKILL.md    # Alex 博客写作风格 skill（同步到 ~/.agents/skills/）
powershell/
├── Microsoft.PowerShell_profile.ps1   # $PROFILE（UTF-8 BOM）
└── scripts/                           # 独立脚本（小写 scripts\）
    ├── mac-mini.ps1                   # smac/wmac Mac mini 显示器控制
    └── Add-StartMenuShortcuts.ps1     # sm-update 开始菜单快捷方式同步
nvim/  rime/  starship/  zshconfig/  'kitty config/'
```

> **注意**：AGENTS.md / CLAUDE.md 位于 `agents/` 子目录，Agent 若默认只扫描项目根目录，需在工具配置中把 `agents/AGENTS.md`（或 `agents/CLAUDE.md`）加入加载范围，或手动粘贴使用。

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

## Skill 同步（触发词：「同步 skill」「同步 agents」）

- 仓库 `agents/skills/` 是 skill 的跨设备备份源，本机活跃目录为 `~/.agents/skills/`（各 Agent 共享）。
- 新增/修改 skill 后：更新 `agents/skills/<name>/SKILL.md`，并同步到本机 `~/.agents/skills/<name>/`。
- commit（conventional commits）+ push 到 `origin main`。
