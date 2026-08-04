<#
.SYNOPSIS
    Mac mini 显示器控制（通过 SSH 远程执行）
.DESCRIPTION
    提供 smac / wmac / wmac-v / wmac-full 四个操作，与 PowerShell profile 中的函数等价：
      smac      : blank macOS display, keep the system awake（熄屏）
      wmac      : wake macOS display + restart deskflow client（唤醒 + 重启 deskflow）
      wmac-v    : wmac with verbose output（详细输出）
      wmac-full : full wake routine（唤醒 + deskflow 重启 + 验证）
    前置条件：~/.ssh/config 中已配置 Host mac-mini。
.PARAMETER Action
    要执行的操作，可选 smac / wmac / wmac-v / wmac-full，默认 wmac。
.EXAMPLE
    .\mac-mini.ps1 smac
    .\mac-mini.ps1 wmac-full
#>
param(
    [ValidateSet('smac', 'wmac', 'wmac-v', 'wmac-full')]
    [string]$Action = 'wmac'
)

switch ($Action) {
    'smac' {
        ssh mac-mini "pmset displaysleepnow"
    }
    'wmac' {
        ssh mac-mini "caffeinate -u -t 2"
        ssh mac-mini "launchctl kickstart -k gui/501/com.deskflow.client"
    }
    'wmac-v' {
        Write-Host "[wmac-v] waking macOS display..." -ForegroundColor Cyan
        ssh mac-mini "caffeinate -u -t 2"
        Write-Host "[wmac-v] restarting deskflow client..." -ForegroundColor Cyan
        ssh mac-mini "launchctl kickstart -k gui/501/com.deskflow.client"
        Write-Host "[wmac-v] done." -ForegroundColor Green
    }
    'wmac-full' {
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
}
