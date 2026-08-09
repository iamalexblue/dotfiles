# ==============================================================================
# 0. 鏋侀€熷惎鍔ㄦ牳蹇冧紭鍖?(蹇呴』鏀惧湪鏈€鍓?
# ==============================================================================
# 绂佺敤 PowerShell 鑷姩鏇存柊妫€鏌ワ紝娑堥櫎鍚姩鏃剁殑鑱旂綉寤惰繜鍜屽脊绐?
$env:POWERSHELL_UPDATECHECK = "Off"

# ==============================================================================
# 1. 妯″潡鍔犺浇 (杞婚噺绾?
# ==============================================================================
# PSReadLine: 鍛戒护琛岀紪杈戝寮?(蹇呴€?
Import-Module PSReadLine

# Starship: 鏋侀€熸彁绀虹寮曟搸 (鏇夸唬 Oh My Posh + posh-git)
# 纭繚宸插畨瑁? choco install starship
if ((Get-Command starship -ErrorAction SilentlyContinue) -and [Environment]::UserInteractive -and $Host.UI.SupportsVirtualTerminal -and $env:TERM -ne 'dumb') {
    Invoke-Expression (&starship init powershell)
}

# ==============================================================================
# 2. PSReadLine 浜や簰璁剧疆 (淇濇寔楂樻晥鎿嶄綔涔犳儻)
# ==============================================================================
# PSReadLine 鐨勯娴?鍘嗗彶鎼滅储渚濊禆铏氭嫙缁堢锛岄潪浜や簰浼氳瘽锛堝 ssh 杩滅▼鍛戒护锛変笅浼氭姤閿欙紝鏁呬粎鍦ㄤ氦浜掑紡缁堢鍚敤銆?
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
# 3. 鐜鍙橀噺閰嶇疆
# ==============================================================================
# 鍏佽鐩存帴杩愯 .py 鑴氭湰 (渚嬪: script.py 鑰屼笉鏄?python script.py)
if ($env:PATHEXT -notlike "*;.py*") {
    $env:PATHEXT += ";.py"
}

# ==============================================================================
# 4. 瀹炵敤鍑芥暟瀹氫箟 (浠呭湪璋冪敤鏃舵墽琛岋紝闆跺惎鍔ㄥ紑閿€)
# ==============================================================================

# [鎵嬪姩鏇存柊] 浠呮洿鏂?Python pip 鍖?
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
# 5. 鍒悕璁剧疆 (Alias)
# ==============================================================================
# 缂栬瘧: make -> nmake (闅愯棌 logo)
function MakeThings { nmake.exe $args -nologo }
Set-Alias -Name make -Value MakeThings

# 鏇存柊: os-update -> 瑙﹀彂 pip 鏇存柊
Set-Alias -Name os-update -Value Update-PipPackages

# 鐩綍: ls (绠€鐣?, ll (璇︾粏)
function ListDirectory { (Get-ChildItem).Name; Write-Host("") }
Set-Alias -Name ls -Value ListDirectory
Set-Alias -Name ll -Value Get-ChildItem

# 鎵撳紑: open . -> 璧勬簮绠＄悊鍣ㄦ墦寮€褰撳墠鐩綍
function OpenCurrentFolder { param($Path = '.') ; Invoke-Item $Path }
Set-Alias -Name open -Value OpenCurrentFolder

# ==============================================================================
# 6. 缃戠粶宸ュ叿鍒悕
# ==============================================================================
function Get-AllNic { Get-NetAdapter | Sort-Object -Property MacAddress }
Set-Alias -Name getnic -Value Get-AllNic

function Get-IPv4Routes { Get-NetRoute -AddressFamily IPv4 | Where-Object { $_.NextHop -ne '0.0.0.0' } }
Set-Alias -Name getip -Value Get-IPv4Routes

function Get-IPv6Routes { Get-NetRoute -AddressFamily IPv6 | Where-Object { $_.NextHop -ne '::' } }
Set-Alias -Name getip6 -Value Get-IPv6Routes

# ==============================================================================
# 7. 浠ｇ悊蹇€熷垏鎹?(浼樺寲鐗堬細甯︾姸鎬佸弽棣?
# ==============================================================================
# 鍋囪浣犵殑浠ｇ悊鏈湴绔彛鏄?23333锛屽鏈変笉鍚岃淇敼姝ゅ
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
# Hermes Agent 鈥?auto-start dashboard in background,
# then launch the CLI.  hermesd opens the web UI.
# ==============================================================================

$hermesExe = Join-Path $env:LOCALAPPDATA "hermes\hermes-agent\venv\Scripts\hermes.exe"

function global:hermes {
    $alive = Test-NetConnection -ComputerName 127.0.0.1 -Port 9119 `
        -InformationLevel Quiet `
        -WarningAction SilentlyContinue `
        -ErrorAction SilentlyContinue
    if (-not $alive) {
        Write-Host "馃殌 Dashboard 鏈繍琛岋紝姝ｅ湪鍚庡彴鍚姩..." -ForegroundColor Cyan
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
        Write-Host "馃殌 Dashboard 鏈繍琛岋紝姝ｅ湪鍚庡彴鍚姩..." -ForegroundColor Cyan
        Start-Process -FilePath $hermesExe `
            -ArgumentList "dashboard", "--skip-build", "--no-open" `
            -WindowStyle Hidden
        Start-Sleep -Seconds 3
    }
    Start-Process "http://127.0.0.1:9119"
}

New-Alias -Name hd -Value hermesd -Force

# FlClash 宕╂簝蹇€熶慨澶?
function global:fix-clash {
    Write-Host "=== FlClash 宕╂簝淇 ===" -ForegroundColor Cyan
    # 鍏堟櫘閫氭潈闄愭潃锛屾潃涓嶆帀鐨勬棤瑙?
    Get-Process -Name "FlClash", "FlClashCore" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    # Helper 鏄郴缁熸湇鍔★紝寰楃敤 gsudo 鎻愭潈
    gsudo taskkill /f /im FlClashHelperService.exe 2>$null
    Start-Sleep -Seconds 1
    $d = "$env:APPDATA\com.follow\clash"

    # 杞婚噺淇锛氬彧鍒犵紦瀛樺拰閿?
    Write-Host "[杞婚噺] 娓呯悊缂撳瓨鍜岄攣鏂囦欢..."
    Remove-Item "$d\cache.db", "$d\cache.db-wal", "$d\cache.db-shm", "$d\FlClash.lock" -Force -ErrorAction SilentlyContinue
    Remove-Item "$d\temp\*" -Recurse -Force -ErrorAction SilentlyContinue

    # 娣卞害淇锛氳繕涓嶈鐨勮瘽鍒?config 鍜屽亸濂斤紝淇濈暀璁㈤槄
    Write-Host "[娣卞害] 閲嶇疆杩愯閰嶇疆锛堜繚鐣欒闃?瑙勫垯锛?.."
    Remove-Item "$d\config.yaml", "$d\config.json", "$d\shared_preferences.json", "$d\database.sqlite" -Force -ErrorAction SilentlyContinue
    Remove-Item "$d\database.sqlite-wal", "$d\database.sqlite-shm" -Force -ErrorAction SilentlyContinue

    Write-Host "淇瀹屾垚锛岄噸鏂版墦寮€ FlClash 鍗冲彲銆? -ForegroundColor Green
    Write-Host "鎻愮ず锛氳闃呭拰瑙勫垯鏂囦欢宸蹭繚鐣欙紝鍚姩鍚庝細鑷姩閲嶅缓閰嶇疆銆? -ForegroundColor Yellow
}
function global:sudo { gsudo @Args }
Remove-Alias -Name sudo -Force -ErrorAction SilentlyContinue

# Windows 鍘熺敓 btop锛歡sudo 鎻愭潈锛屽湪褰撳墠缁堢杩愯锛堜笉寮规柊绐楀彛锛?
function global:btop { gsudo btop $Args }

# gsudo PowerShell 妯″潡锛堝惎鐢?gsudo !! 绛夎娉曪級
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
# 寮€濮嬭彍鍗曞揩鎹锋柟寮忓悓姝ワ紙璁?PowerToys CmdPal / Win 鎼滅储鑳芥悳鍒版病鏈夊揩鎹锋柟寮忕殑搴旂敤锛?
# 鑴氭湰浣嶇疆: <profile>\Scripts\Add-StartMenuShortcuts.ps1
#   sm-update            # 鎵弿榛樿鐩綍 + 娉ㄥ唽琛?Uninstall 椤?
#   sm-update -Path X    # 棰濆鎵弿鑷畾涔夌洰褰?
#   sm-update -WhatIf    # 婕旂粌妯″紡
# ==============================================================================
function global:sm-update {
    $script = Join-Path (Split-Path $PROFILE) 'scripts\Add-StartMenuShortcuts.ps1'
    if (-not (Test-Path -LiteralPath $script)) {
        Write-Warning "鎵句笉鍒拌剼鏈? $script"
        return
    }
    & $script @Args
}
