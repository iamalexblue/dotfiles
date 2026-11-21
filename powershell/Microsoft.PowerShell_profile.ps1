# ==============================================================================
# 0. 极速启动核心优化 (必须放在最前)
# ==============================================================================
# 禁用 PowerShell 自动更新检查，消除启动时的联网延迟和弹窗
$env:POWERSHELL_UPDATECHECK = "Off"

# ==============================================================================
# 1. 模块加载 (轻量级)
# ==============================================================================
# PSReadLine: 命令行编辑增强 (必选)
Import-Module PSReadLine

# Starship: 极速提示符引擎 (替代 Oh My Posh + posh-git)
# 确保已安装: choco install starship
if ((Get-Command starship -ErrorAction SilentlyContinue) -and [Environment]::UserInteractive -and $Host.UI.SupportsVirtualTerminal -and $env:TERM -ne 'dumb') {
    Invoke-Expression (&starship init powershell)
}

# ==============================================================================
# 2. PSReadLine 交互设置 (保持高效操作习惯)
# ==============================================================================
# PSReadLine 的预测/历史搜索依赖虚拟终端，非交互会话（如 ssh 远程命令）下会报错，故仅在交互式终端启用。
if ($Host.UI.SupportsVirtualTerminal -and [Environment]::UserInteractive) {
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineKeyHandler -Key "Tab" -Function MenuComplete
    Set-PSReadLineKeyHandler -Key "Ctrl+d" -Function ViExit
    Set-PSReadLineKeyHandler -Key "Ctrl+z" -Function Undo
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
}

# ==============================================================================
# 3. 环境变量配置
# ==============================================================================
# 允许直接运行 .py 脚本 (例如: script.py 而不是 python script.py)
if ($env:PATHEXT -notlike "*;.py*") {
    $env:PATHEXT += ";.py"
}

# ==============================================================================
# 4. 实用函数定义 (仅在调用时执行，零启动开销)
# ==============================================================================

# [手动更新] 仅更新 Python pip 包
function Update-PipPackages {
    Write-Host ">>> Updating pip packages..." -ForegroundColor Cyan
    try {
        python -m pip install --upgrade pip -q
        $outdated = pip list --outdated --format=json | ConvertFrom-Json
        if ($outdated.Count -eq 0) {
            Write-Host ">>> All packages are up to date." -ForegroundColor Green
        } else {
            foreach ($pkg in $outdated) {
                Write-Host "Updating $($pkg.name)..." -NoNewline
                pip install -U $pkg.name -q
                Write-Host " Done" -ForegroundColor Gray
            }
            Write-Host ">>> Update finished." -ForegroundColor Green
        }
    } catch {
        Write-Warning "Update failed. Check network or Python installation."
    }
}

# ==============================================================================
# 5. 别名设置 (Alias)
# ==============================================================================
# 编译: make -> nmake (隐藏 logo)
function MakeThings { nmake.exe $args -nologo }
Set-Alias -Name make -Value MakeThings

# 更新: os-update -> 触发 pip 更新
Set-Alias -Name os-update -Value Update-PipPackages

# 目录: ls (简略), ll (详细)
function ListDirectory { (Get-ChildItem).Name; Write-Host("") }
Set-Alias -Name ls -Value ListDirectory
Set-Alias -Name ll -Value Get-ChildItem

# 打开: open . -> 资源管理器打开当前目录
function OpenCurrentFolder { param($Path = '.') ; Invoke-Item $Path }
Set-Alias -Name open -Value OpenCurrentFolder

# ==============================================================================
# 6. 网络工具别名
# ==============================================================================
function Get-AllNic { Get-NetAdapter | Sort-Object -Property MacAddress }
Set-Alias -Name getnic -Value Get-AllNic

function Get-IPv4Routes { Get-NetRoute -AddressFamily IPv4 | Where-Object { $_.NextHop -ne '0.0.0.0' } }
Set-Alias -Name getip -Value Get-IPv4Routes

function Get-IPv6Routes { Get-NetRoute -AddressFamily IPv6 | Where-Object { $_.NextHop -ne '::' } }
Set-Alias -Name getip6 -Value Get-IPv6Routes

# ==============================================================================
# 7. 代理快速切换 (优化版：带状态反馈)
# ==============================================================================
# 假设你的代理本地端口是 23333，如有不同请修改此处
$PROXY_ADDR = "http://10.10.10.10:6152"

function pon { 
    $env:HTTP_PROXY = $PROXY_ADDR
    Write-Host "[Proxy] HTTP Proxy ON ($PROXY_ADDR)" -ForegroundColor Green 
}

function pson { 
    $env:HTTPS_PROXY = $PROXY_ADDR
    Write-Host "[Proxy] HTTPS Proxy ON ($PROXY_ADDR)" -ForegroundColor Green 
}

function apon { 
    $env:HTTP_PROXY = $PROXY_ADDR
    $env:HTTPS_PROXY = $PROXY_ADDR
    Write-Host "[Proxy] ALL Proxies ON ($PROXY_ADDR)" -ForegroundColor Green 
}

function poff { 
    $env:HTTP_PROXY = ""
    Write-Host "[Proxy] HTTP Proxy OFF" -ForegroundColor Yellow 
}

function psoff { 
    $env:HTTPS_PROXY = ""
    Write-Host "[Proxy] HTTPS Proxy OFF" -ForegroundColor Yellow 
}

function apoff { 
    $env:HTTP_PROXY = ""
    $env:HTTPS_PROXY = ""
    Write-Host "[Proxy] ALL Proxies OFF" -ForegroundColor Yellow 
}

# ==============================================================================
# Hermes Agent — auto-start dashboard in background,
# then launch the CLI.  hermesd opens the web UI.
# ==============================================================================

$hermesExe = Join-Path $env:LOCALAPPDATA "hermes\hermes-agent\venv\Scripts\hermes.exe"

function global:hermes {
    # update 命令：跳过 dashboard 自启，直接透传给 hermes 走更新流程
    if ($Args.Count -gt 0 -and $Args[0] -eq 'update') {
        & $hermesExe @Args
        return
    }
    $alive = Test-NetConnection -ComputerName 127.0.0.1 -Port 9119 `
        -InformationLevel Quiet `
        -WarningAction SilentlyContinue `
        -ErrorAction SilentlyContinue
    if (-not $alive) {
        Write-Host "🚀 Dashboard 未运行，正在后台启动..." -ForegroundColor Cyan
        Start-Process -FilePath $hermesExe `
            -ArgumentList "dashboard", "--skip-build", "--no-open" `
            -WindowStyle Hidden
        Start-Sleep -Seconds 3
    }
    & $hermesExe @Args
}

function global:hermesd {
    $alive = Test-NetConnection -ComputerName 127.0.0.1 -Port 9119 `
        -InformationLevel Quiet `
        -WarningAction SilentlyContinue `
        -ErrorAction SilentlyContinue
    if (-not $alive) {
        Write-Host "🚀 Dashboard 未运行，正在后台启动..." -ForegroundColor Cyan
        Start-Process -FilePath $hermesExe `
            -ArgumentList "dashboard", "--skip-build", "--no-open" `
            -WindowStyle Hidden
        Start-Sleep -Seconds 3
    }
    Start-Process "http://127.0.0.1:9119"
}

New-Alias -Name hd -Value hermesd -Force

# # FlClash 崩溃快速修复
# function global:fix-clash {
#     Write-Host "=== FlClash 崩溃修复 ===" -ForegroundColor Cyan
#     # 先普通权限杀，杀不掉的无视
#     Get-Process -Name "FlClash", "FlClashCore" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
#     # Helper 是系统服务，得用 gsudo 提权
#     gsudo taskkill /f /im FlClashHelperService.exe 2>$null
#     Start-Sleep -Seconds 1
#     $d = "$env:APPDATA\com.follow\clash"

#     # 轻量修复：只删缓存和锁
#     Write-Host "[轻量] 清理缓存和锁文件..."
#     Remove-Item "$d\cache.db", "$d\cache.db-wal", "$d\cache.db-shm", "$d\FlClash.lock" -Force -ErrorAction SilentlyContinue
#     Remove-Item "$d\temp\*" -Recurse -Force -ErrorAction SilentlyContinue

#     # 深度修复：还不行的话删 config 和偏好，保留订阅
#     Write-Host "[深度] 重置运行配置（保留订阅/规则）..."
#     Remove-Item "$d\config.yaml", "$d\config.json", "$d\shared_preferences.json", "$d\database.sqlite" -Force -ErrorAction SilentlyContinue
#     Remove-Item "$d\database.sqlite-wal", "$d\database.sqlite-shm" -Force -ErrorAction SilentlyContinue

#     Write-Host "修复完成，重新打开 FlClash 即可。" -ForegroundColor Green
#     Write-Host "提示：订阅和规则文件已保留，启动后会自动重建配置。" -ForegroundColor Yellow
# }
function global:sudo { gsudo @Args }
Remove-Alias -Name sudo -Force -ErrorAction SilentlyContinue

# Windows 原生 btop：gsudo 提权，在当前终端运行（不弹新窗口）
function global:btop { gsudo btop $Args }

# gsudo PowerShell 模块（启用 gsudo !! 等语法）
$env:PSModulePath = "$env:PSModulePath;D:\scoop\modules"
Import-Module gsudoModule

#f45873b3-b655-43a6-b217-97c00aa0db58 PowerToys CommandNotFound module

Import-Module -Name Microsoft.WinGet.CommandNotFound
#f45873b3-b655-43a6-b217-97c00aa0db58

# ==============================================================================
# Mac mini 控制（deskflow 主机）
# 脚本本体: <profile>\Scripts\MacMiniControl.ps1
#
# 命名规则：mac 开头 + 动词。一条命令一件事。
#   mac-wake      唤醒 Mac（点亮显示器 + 重启 deskflow）← 最常用
#   mac-sleep     让 Mac 显示器睡眠（系统保持唤醒）
#   mac-status    看一眼现状（显示器/deskflow/登录状态）
#   mac-fix       只重启 deskflow，不碰显示器
#   mac-doctor    出问题了跑这个，把输出发我
#   mac-edit      用 nvim 打开脚本
#   mac-help      打印用法（忘了命令叫啥就跑这个）
#
# 旧的 wmac / wmac-v / wmac-full / smac 已删除 —— 那三个只有 sleep 时长和日志多少不同，
# 核心动作完全一样，现在统一成 mac-wake / mac-sleep。
# ==============================================================================
function Invoke-MacControl {
    param([string]$MacAction)
    $s = Join-Path (Split-Path $PROFILE) 'Scripts\MacMiniControl.ps1'
    if (-not (Test-Path -LiteralPath $s)) {
        Write-Warning "找不到脚本: $s"
        return
    }
    & $s -Action $MacAction @args
}

function global:mac-wake   { Invoke-MacControl 'wake' @args }
function global:mac-sleep  { Invoke-MacControl 'sleep' @args }
function global:mac-status { Invoke-MacControl 'status' @args }
function global:mac-fix    { Invoke-MacControl 'deskflow' @args }
function global:mac-doctor { Invoke-MacControl 'doctor' @args }

function global:mac-edit { nvim (Join-Path (Split-Path $PROFILE) 'Scripts\MacMiniControl.ps1') }

function global:Get-DisplayWidth {
    # 东亚宽字符占 2 格，ASCII 占 1 格。PowerShell 的 -f / PadRight 只按字符数算，中文会错位。
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return 0 }
    $total = 0
    foreach ($ch in $Text.ToCharArray()) {
        $cp = [int]$ch
        $isWide = $false
        if ($cp -ge 0x1100 -and $cp -le 0x115F) { $isWide = $true }
        elseif ($cp -ge 0x2E80 -and $cp -le 0xA4CF) { $isWide = $true }
        elseif ($cp -ge 0xAC00 -and $cp -le 0xD7A3) { $isWide = $true }
        elseif ($cp -ge 0xF900 -and $cp -le 0xFAFF) { $isWide = $true }
        elseif ($cp -ge 0xFE30 -and $cp -le 0xFE6F) { $isWide = $true }
        elseif ($cp -ge 0xFF00 -and $cp -le 0xFF60) { $isWide = $true }
        elseif ($cp -ge 0xFFE0 -and $cp -le 0xFFE6) { $isWide = $true }
        if ($isWide) { $total = $total + 2 } else { $total = $total + 1 }
    }
    return $total
}

function global:Format-DisplayPad {
    # 按“显示宽度”右补空格，而不是按字符数
    param([string]$Text, [int]$Width)
    $current = Get-DisplayWidth -Text $Text
    $need = $Width - $current
    if ($need -lt 0) { $need = 0 }
    return ($Text + (' ' * $need))
}

function global:mac-help {
    $cTitle = 'Cyan'; $cDim = 'DarkGray'; $cCmd = 'Green'; $cTag = 'DarkYellow'; $cEx = 'Gray'
    $rule = '  ' + ('-' * 60)

    Write-Host ''
    Write-Host '  Mac mini 控制' -ForegroundColor $cTitle
    Write-Host $rule -ForegroundColor $cDim

    $rows = @(
        @('mac-wake',   '唤醒 Mac：点亮显示器 + 重启 deskflow', '最常用'),
        @('mac-sleep',  '让 Mac 显示器睡眠（系统保持唤醒）', ''),
        @('mac-status', '查看现状：deskflow / 登录状态', ''),
        @('mac-fix',    '只重启 deskflow，不碰显示器', ''),
        @('mac-doctor', '完整体检，出问题先跑这个', '排障'),
        @('mac-edit',   '用 nvim 打开控制脚本', ''),
        @('mac-help',   '显示这份帮助', '')
    )
    foreach ($r in $rows) {
        $name = Format-DisplayPad -Text $r[0] -Width 12
        $desc = Format-DisplayPad -Text $r[1] -Width 40
        $tail = ''
        if ($r[2] -ne '') { $tail = '[ ' + $r[2] + ' ]' }
        Write-Host ('   ' + $name) -ForegroundColor $cCmd -NoNewline
        Write-Host ($desc) -NoNewline
        if ($tail -ne '') { Write-Host $tail -ForegroundColor $cTag } else { Write-Host '' }
    }

    Write-Host ''
    Write-Host '  通用参数（mac-wake / mac-sleep / mac-fix 都适用）' -ForegroundColor $cTitle
    Write-Host $rule -ForegroundColor $cDim
    $opts = @(
        @('-WakeSeconds <秒>', 'caffeinate 唤醒持续秒数，默认 2'),
        @('-Timeout <秒>',     'SSH 连接超时，默认 15'),
        @('-SshHost <别名>',   'ssh config 里的主机名，默认 mac-mini'),
        @('-Force',            '进程已在跑也强行走一遍重启'),
        @('-DryRun',           '只打印将要发到远端的脚本，不真连')
    )
    foreach ($o in $opts) {
        $opt = Format-DisplayPad -Text $o[0] -Width 20
        Write-Host ('   ' + $opt + $o[1]) -ForegroundColor $cDim
    }

    Write-Host ''
    Write-Host '  例子' -ForegroundColor $cTitle
    Write-Host $rule -ForegroundColor $cDim
    $examples = @(
        'mac-wake                    # 日常，唤醒 + 重启 deskflow',
        'mac-wake -WakeSeconds 10    # 屏幕太困，多唤一会儿',
        'mac-status                  # 先看看现在什么情况',
        'mac-doctor                  # 出问题了，体检'
    )
    foreach ($line in $examples) { Write-Host ('   ' + $line) -ForegroundColor $cEx }

    Write-Host ''
    Write-Host '  说明' -ForegroundColor $cTitle
    Write-Host $rule -ForegroundColor $cDim
    Write-Host '   脚本本体       <profile>\Scripts\MacMiniControl.ps1' -ForegroundColor $cDim
    Write-Host '   SSH 免密       走 Keyguard agent，配置在 ~/.ssh/config' -ForegroundColor $cDim
    Write-Host '   启动方式       Deskflow 1.27+ 用 launchctl submit' -ForegroundColor $cDim
    Write-Host '                  （open -a 在 SSH 会话里会秒退）' -ForegroundColor $cDim
    Write-Host ''
}

# 旧名字（wmac / wmac-v / wmac-full / smac）已移除，统一用上面的 mac-* 命令。
# ==============================================================================
# 开始菜单快捷方式同步（让 PowerToys CmdPal / Win 搜索能搜到没有快捷方式的应用）
# 脚本位置: <profile>\Scripts\Add-StartMenuShortcuts.ps1
#   sm-update            # 扫描默认目录 + 注册表 Uninstall 项
#   sm-update -Path X    # 额外扫描自定义目录
#   sm-update -WhatIf    # 演练模式
# ==============================================================================
function global:sm-update {
    $script = Join-Path (Split-Path $PROFILE) 'Scripts\Add-StartMenuShortcuts.ps1'
    if (-not (Test-Path -LiteralPath $script)) {
        Write-Warning "找不到脚本: $script"
        return
    }
    & $script @Args
}

# net-stats: 查看网络守护脚本状态（路由器智能重启 + DHCP 主备切换）
function net-stats {
    ssh -o BatchMode=yes mac-mini '~/.orbstack/bin/orb -m orb-debian sh -c "net-stats"'
}

# ==============================================================================
# 8. 目录快捷跳转 & profile 编辑
# ==============================================================================
# cd 原本是 Set-Location 的别名，而 PowerShell 中别名优先级高于函数，
# 所以要先移除别名，再定义同名函数拦截：dload=下载目录, dev=开发目录
Remove-Alias -Name cd -Force -ErrorAction SilentlyContinue

function cd {
    param([Parameter(Position = 0)] [string] $Path)
    switch ($Path) {
        'dload' {
            $dl = [Environment]::ExpandEnvironmentVariables(
                (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders').'{374DE290-123F-4565-9164-39C4925E467B}')
            Set-Location -LiteralPath $dl
        }
        'dev'   { Set-Location -LiteralPath 'D:\Dev\Fork' }
        default {
            if ([string]::IsNullOrEmpty($Path)) { Set-Location ~ }
            else { Set-Location $Path }
        }
    }
}

# ps1edit: 用 nvim 打开当前 PowerShell 配置文件
function ps1edit { nvim $PROFILE }

# sm-edit: 用 nvim 打开快捷方式同步脚本
function sm-edit { nvim (Join-Path (Split-Path $PROFILE) 'Scripts\Add-StartMenuShortcuts.ps1') }
