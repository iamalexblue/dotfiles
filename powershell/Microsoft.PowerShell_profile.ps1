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

# FlClash 崩溃快速修复
function global:fix-clash {
    Write-Host "=== FlClash 崩溃修复 ===" -ForegroundColor Cyan
    # 先普通权限杀，杀不掉的无视
    Get-Process -Name "FlClash", "FlClashCore" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    # Helper 是系统服务，得用 gsudo 提权
    gsudo taskkill /f /im FlClashHelperService.exe 2>$null
    Start-Sleep -Seconds 1
    $d = "$env:APPDATA\com.follow\clash"

    # 轻量修复：只删缓存和锁
    Write-Host "[轻量] 清理缓存和锁文件..."
    Remove-Item "$d\cache.db", "$d\cache.db-wal", "$d\cache.db-shm", "$d\FlClash.lock" -Force -ErrorAction SilentlyContinue
    Remove-Item "$d\temp\*" -Recurse -Force -ErrorAction SilentlyContinue

    # 深度修复：还不行的话删 config 和偏好，保留订阅
    Write-Host "[深度] 重置运行配置（保留订阅/规则）..."
    Remove-Item "$d\config.yaml", "$d\config.json", "$d\shared_preferences.json", "$d\database.sqlite" -Force -ErrorAction SilentlyContinue
    Remove-Item "$d\database.sqlite-wal", "$d\database.sqlite-shm" -Force -ErrorAction SilentlyContinue

    Write-Host "修复完成，重新打开 FlClash 即可。" -ForegroundColor Green
    Write-Host "提示：订阅和规则文件已保留，启动后会自动重建配置。" -ForegroundColor Yellow
}
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

# ===== Mac mini display control (ported from Linux aliases) =====
# smac      : blank macOS display, keep the system awake
# wmac      : wake macOS display + restart deskflow client
# wmac-v    : wmac with verbose output
# wmac-full : full wake routine (wake + deskflow restart + verify)

function smac {
    ssh mac-mini "pmset displaysleepnow"
}

function wmac {
    ssh mac-mini "caffeinate -u -t 2"
    ssh mac-mini "launchctl kickstart -k gui/501/com.deskflow.client"
}

function wmac-v {
    Write-Host "[wmac-v] waking macOS display..." -ForegroundColor Cyan
    ssh mac-mini "caffeinate -u -t 2"
    Write-Host "[wmac-v] restarting deskflow client..." -ForegroundColor Cyan
    ssh mac-mini "launchctl kickstart -k gui/501/com.deskflow.client"
    Write-Host "[wmac-v] done." -ForegroundColor Green
}

function wmac-full {
    Write-Host "[wmac-full] waking macOS display..." -ForegroundColor Cyan
    ssh mac-mini "caffeinate -u -t 5"
    Start-Sleep -Seconds 2
    Write-Host "[wmac-full] restarting deskflow client..." -ForegroundColor Cyan
    ssh mac-mini "launchctl kickstart -k gui/501/com.deskflow.client"
    Start-Sleep -Seconds 3
$out = ssh mac-mini "launchctl list | grep deskflow" 2>$null
    if ($LASTEXITCODE -eq 0 -and $out) {
        Write-Host "[wmac-full] deskflow running: $out" -ForegroundColor Green
    } else {
        Write-Host "[wmac-full] WARNING: deskflow not detected." -ForegroundColor Yellow
    }
}

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
