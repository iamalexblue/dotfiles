
# ============================================================
# Proxy Auto-Config (mihomo)
# 使用: pon 开启代理 | poff 关闭代理
# ============================================================

function proxy-on {
    $env:HTTP_PROXY  = "http://127.0.0.1:7890"
    $env:HTTPS_PROXY = "http://127.0.0.1:7890"
    Write-Host "✅ 代理已开启 (http://127.0.0.1:7890)" -ForegroundColor Green
}

function proxy-off {
    $env:HTTP_PROXY  = ""
    $env:HTTPS_PROXY = ""
    Write-Host "❌ 代理已关闭" -ForegroundColor Yellow
}

New-Alias -Name pon  -Value proxy-on  -Force
New-Alias -Name poff -Value proxy-off -Force

# ============================================================
# Hermes Agent — auto-start dashboard in background,
# then launch the CLI.  hermesd opens the web UI.
# ============================================================

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
    Start-Process "http://127.0.0.1:9119"
}

New-Alias -Name hd -Value hermesd -Force

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

# ============================================================
# 开始菜单快捷方式同步 (sm-update)
# 为 PowerToys CmdPal / Win 搜索补齐没有快捷方式的应用
# 脚本: scripts\Add-StartMenuShortcuts.ps1
#   sm-update            # 扫描注册表 Uninstall + 便携目录，补建快捷方式
#   sm-update -CleanVersion  # 去掉应用名里的版本号
#   sm-update -Prune     # 清理失效快捷方式
#   sm-update -Refresh   # 刷新 target 变化的快捷方式
#   sm-update -WhatIf    # 演练模式
#   sm-update -Help      # 查看完整用法
# ============================================================
function global:sm-update {
    $script = Join-Path (Split-Path $PROFILE) 'scripts\Add-StartMenuShortcuts.ps1'
    if (-not (Test-Path -LiteralPath $script)) {
        Write-Warning "找不到脚本: $script"
        return
    }
    & $script @Args
}
