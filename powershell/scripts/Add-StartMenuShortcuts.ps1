# ==============================================================================
# Add-StartMenuShortcuts.ps1  (v2)
# ------------------------------------------------------------------------------
# 用途：为「便携软件 / 只写注册表、没生成快捷方式的已安装程序」批量生成
#       开始菜单快捷方式 (.lnk)，让 PowerToys Command Palette (CmdPal) 和
#       原生 Win 搜索都能搜到它们。
#
# 为什么需要：CmdPal 的 "Installed Apps" 扩展只扫描开始菜单 / 桌面快捷方式
#             和固定安装目录；不在这些位置的应用它搜不到。补一个快捷方式即可。
#
# 设计原则：只挑「主程序」，绝不把内部组件/辅助 exe（crash reporter、
#           uninstaller、driver、node_modules、copilot sdk 等）塞进开始菜单。
#
# 用法（用 alias: sm-update 执行）：
#     sm-update                          # 扫描注册表 Uninstall 项 + 便携目录 + scoop
#     sm-update D:\Apps E:\Tools         # 额外扫描自定义便携目录（位置参数，可多个）
#     sm-update -Path D:\Apps            # 同上，显式命名
#     sm-update -CleanVersion            # 去掉名称里的版本号
#     sm-update -Refresh                 # 已有快捷方式也重新指向最新 exe
#     sm-update -Prune                   # 只删「本脚本建过、目标已消失」的快捷方式
#     sm-update -Reload                  # 跑完重启 explorer + PowerToys 刷新索引
#     sm-update -WhatIf                  # 演练模式，只看会做什么
# ==============================================================================

#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    # 额外要扫描的便携目录（可传多个，可直接跟在命令后面）
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Path,

    # 便携软件根目录：每个根下面「子目录」里的主 exe 会被考虑。
    # 不传则自动使用 $env:SCOOP\apps + 常见用户目录。
    [string[]]$PortableRoots,

    # 便携目录向下找 exe 的层数（1=只看一层子目录）
    [ValidateRange(1, 6)]
    [int]$Depth = 2,

    # 已有同名快捷方式时也重新指向找到的最新 exe（target 不一致则刷新）
    [switch]$Refresh,

    # 只删除「本脚本创建过、且目标 exe 已消失」的快捷方式（靠 manifest 记录）
    [switch]$Prune,

    # 去掉应用名里的版本号（只对新建/刷新时生效）
    [switch]$CleanVersion,

    # 跑完重启 explorer + PowerToys，让 CmdPal 立刻重建索引
    [switch]$Reload,

    # 不扫描 scoop 应用
    [switch]$NoScoop,

    # 显示用法帮助（不执行任何操作）
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

# ------------------------------------------------------------------------------
# 用法帮助（sm-update -Help）
# ------------------------------------------------------------------------------
if ($Help) {
    $helpText = @'

 Add-StartMenuShortcuts —— 为 PowerToys CmdPal / Win 搜索补齐开始菜单快捷方式

 用法（= alias sm-update）：
   sm-update                              扫描注册表 Uninstall 项 + 便携目录 + scoop
   sm-update D:\Apps E:\Tools             额外扫描自定义便携目录（可多个）

 参数：
   -Path <目录...>         额外扫描的便携目录（也可直接跟在命令后面）
   -PortableRoots <数组>   便携根目录（默认 $env:SCOOP\apps + ~\Portable + ~\Apps）
   -Depth <n>              便携目录向下找 exe 的层数，默认 2
   -CleanVersion           去掉应用名里的版本号（WPS Office (12.1.0.28022) -> WPS Office）
   -Refresh                已有快捷方式但 target 变了就重新指向
   -Prune                  删除「本脚本建的、目标已消失」的快捷方式
   -Reload                 跑完重启 explorer + PowerToys 刷新 CmdPal 索引
   -NoScoop                不扫描 scoop 应用
   -WhatIf                 演练模式：只列出会做什么，不实际执行
   -Help                   显示本帮助

 组合示例：
   sm-update -CleanVersion                    # 常规 + 去版本号
   sm-update -WhatIf -Prune -CleanVersion     # 先预览所有改动
   sm-update -Prune                           # 清理失效快捷方式
   sm-update -Reload                          # 跑完立刻刷新索引

 安全提示：
   - 只【读】注册表 Uninstall 项，从不写注册表；改动只发生在开始菜单文件夹。
   - -Prune 只动 manifest 里记录过的快捷方式（$env:LOCALAPPDATA\Add-StartMenuShortcuts\manifest.json），
     不会碰你手搓的快捷方式。
   - 正式跑 -Prune / -Refresh 前，建议先加 -WhatIf 看一眼。
'@
    Write-Host $helpText
    return
}

# ------------------------------------------------------------------------------
# 黑名单配置
# ------------------------------------------------------------------------------
# 文件名黑名单（安装器 / 卸载器 / 运行库 / 通用工具，绝不生成快捷方式）
$ExeNameBlacklist = @(
    'uninstall', 'unins000', 'unins001', 'setup', 'install', 'installer',
    'vc_redist', 'vcredist', 'dotnet', 'dotnet-install', 'msiexec',
    'npm', 'npx', 'yarn', 'pnpm', 'nodevars', 'winsw', 'bash', 'sh', 'cmd',
    'powershell', 'pwsh', 'cmdproxy', 'conhost', 'rdpclip', 'notepad',
    # 这些虽然编译成 GUI 子系统，但没有窗口（脚本宿主 / 无控制台解释器）
    'pythonw', 'pyw', 'wscript', 'cscript', 'mshta', 'rundll32'
) | ForEach-Object { $_.ToLowerInvariant() }

# 文件名里出现这些片段就跳过（辅助进程 / 组件）。用 \b 词边界，避免
# "agents anywhere" 被 "agent" 误杀、"Service Manager" 被 "service" 误杀。
$ExeNameDenyRegex = @(
    'crashreport', 'crashsender', 'creporter', 'elevat', 'uninstall',
    'setup', 'installer', 'updater', 'helper', 'daemon', 'proxy', 'shim',
    'diagnostic', 'tunnel', 'devcon', 'tapinstall', 'certmgr',
    'notification', 'host_client', 'host-prep', 'guest', 'sandbox',
    'vsce-sign', 'conpty', 'inno_updater',
    '\bagent\b', '\bservice\b'
)

# 路径黑名单片段（跑到这些目录里的一律是内部组件）
$PathDenyRegex = @(
    'node_modules', 'builtin-plugins', '\.unpacked', '\\resources\\',
    '\\components\\', '\\driver\\', '\\installer\\',
    '\\assets\\utilities\\', '\\redistributables\\',
    '\\common files\\', '\\uninstall\\'
)

# 注册表 DisplayName 噪音（驱动 / 运行库 / SDK 之类根本不值得进开始菜单）
$DisplayNameNoiseRegex = '(?i)\b(driver|drivers|runtime|redistributable|redist|sdk|framework|bootstrapper|provisioning|compatibility database|update for|hotfix|language pack|codec pack)\b'

# 我们创建过的快捷方式清单（-Prune 只认这里面的）
$ManifestDir = Join-Path $env:LOCALAPPDATA 'Add-StartMenuShortcuts'
$ManifestPath = Join-Path $ManifestDir 'manifest.json'

# COM 对象复用（每次 New-Object 都要启动 COM，几百次很慢）
$script:Wsh = New-Object -ComObject WScript.Shell

# 计数器
$script:Created = 0
$script:Refreshed = 0
$script:Planned = 0
$script:Duplicate = 0

# ------------------------------------------------------------------------------
# 读 PE 头判断 exe 是窗口程序还是控制台程序。
# 只给 GUI 程序建快捷方式，能滤掉 90% 的 CLI 噪音（git.exe / sh.exe / make.exe）。
# 读不出来就当 GUI 处理（宁可多一个，不要漏）。
# ------------------------------------------------------------------------------
function Test-IsGuiExe {
    param([string]$ExePath)
    try {
        $fs = [IO.File]::Open($ExePath, 'Open', 'Read', 'ReadWrite')
        try {
            $br = New-Object IO.BinaryReader($fs)
            $fs.Position = 0x3C
            $peOffset = $br.ReadInt32()
            if ($peOffset -le 0 -or $peOffset -gt $fs.Length - 64) { return $true }
            $fs.Position = $peOffset
            if ($br.ReadUInt32() -ne 0x00004550) { return $true }   # "PE\0\0"
            $fs.Position = $peOffset + 0x5C                            # Subsystem 字段
            return ($br.ReadUInt16() -eq 2)                            # 2 = IMAGE_SUBSYSTEM_WINDOWS_GUI
        }
        finally { $fs.Dispose() }
    }
    catch { return $true }
}

# ------------------------------------------------------------------------------
# 判断一个 exe 是否值得生成快捷方式。
# ------------------------------------------------------------------------------
function Test-ExeWorthShortcut {
    param([string]$ExePath)
    $base = [IO.Path]::GetFileNameWithoutExtension($ExePath).ToLowerInvariant()
    $pathL = $ExePath.ToLowerInvariant()

    if ([string]::IsNullOrWhiteSpace($base)) { return $false }
    if ($ExeNameBlacklist -contains $base) { return $false }
    foreach ($s in $ExeNameDenyRegex) { if ($base -match $s) { return $false } }
    foreach ($s in $PathDenyRegex) { if ($pathL -match $s) { return $false } }
    if (-not (Test-IsGuiExe $ExePath)) { return $false }
    return $true
}

# ------------------------------------------------------------------------------
# 把注册表 DisplayIcon 之类的原始字符串解析成真实可用的 exe 路径。
# 能处理：带引号、`,` 分隔的图标索引、"app.exe,0"、"\"app.exe\",0" 等。
# 解析失败或不存在返回 $null。
# ------------------------------------------------------------------------------
function Get-RealExePath {
    param([string]$Raw)
    if ([string]::IsNullOrWhiteSpace($Raw)) { return $null }

    $p = $Raw.Trim()

    # 1) "C:\path\app.exe",0   /  "C:\path\app.exe"
    if ($p -match '^"([^"]+)"\s*(?:,\s*-?\d+\s*)?$') {
        $p = $Matches[1]
    }
    # 2) C:\path\app.exe,0   （路径里没有逗号的常规情况）
    elseif ($p -match '^([^,]+?)\s*,\s*-?\d+\s*$') {
        $p = $Matches[1]
    }
    # 3) 其它怪格式：砍掉第一个逗号之后的内容
    else {
        $p = ($p -split ',')[0]
    }

    $p = $p.Trim().Trim('"').Trim()
    if ([string]::IsNullOrWhiteSpace($p)) { return $null }
    $p = [Environment]::ExpandEnvironmentVariables($p)

    # 只有绝对路径才继续（相对路径的 DisplayIcon 毫无意义，且 GetFullPath 会抛）
    if (-not [IO.Path]::IsPathRooted($p)) { return $null }
    try { $p = [IO.Path]::GetFullPath($p) } catch { return $null }

    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return $null }
    if ($p -notmatch '\.(exe|lnk)$') { return $null }
    return $p
}

# ------------------------------------------------------------------------------
# 清洗快捷方式名：去掉控制字符(null) 与 Windows 文件名非法字符 `<>:"/\|?*`。
# ------------------------------------------------------------------------------
function Get-SafeShortcutName {
    param([string]$Name)
    $clean = $Name -replace '[<>:"/\\|?*\p{Cc}]', ' ' -replace '\s+', ' '
    $clean = $clean.Trim().TrimEnd('.')
    if ([string]::IsNullOrWhiteSpace($clean)) { return $null }
    return $clean
}

# ------------------------------------------------------------------------------
# 去掉应用名里的版本号（-CleanVersion 时调用），尽力而为、可再调。
# ------------------------------------------------------------------------------
function Get-FriendlierName {
    param([string]$Name)
    $n = $Name
    # 1) 去掉括号里的版本号：(v1.2.3) / (12.1.0.28022)
    $n = $n -replace '[\(\[]\s*[vV]?\d+(\.\d+)+[^)\]]*[\)\]]', ''
    # 2) 去掉结尾的 " version X.Y.Z" / " 版本 X.Y.Z"
    $n = $n -replace '\s+(version|版本)\s+[vV]?\d+\.\d+[^\s]*$', ''
    # 3) 去掉结尾裸版本号 " X.Y.Z"（如 PeaZip 11.2.0）
    $n = $n -replace '\s+[vV]?\d+\.\d+[^\s]*$', ''
    $n = ($n -replace '\s+', ' ').Trim()
    if ([string]::IsNullOrWhiteSpace($n)) { return $Name }
    return $n
}

# ------------------------------------------------------------------------------
# 读/写 manifest（记录本脚本创建过的快捷方式）
# ------------------------------------------------------------------------------
function Read-Manifest {
    if (-not (Test-Path -LiteralPath $ManifestPath)) { return @() }
    try {
        $raw = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
        $json = $raw | ConvertFrom-Json
        if ($null -eq $json) { return @() }
        return @($json)
    }
    catch { return @() }
}

function Write-Manifest {
    param([object[]]$Entries)
    if (-not $PSCmdlet.ShouldProcess($ManifestPath, 'Write manifest')) { return }
    if (-not (Test-Path -LiteralPath $ManifestDir)) {
        New-Item -ItemType Directory -Path $ManifestDir -Force | Out-Null
    }
    $list = @($Entries | Where-Object { $_ } | Sort-Object link -Unique)
    ConvertTo-Json -InputObject $list -Depth 3 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8
}

# ------------------------------------------------------------------------------
# 收集所有已有快捷方式名（用户开始菜单 + 桌面 + 公共开始菜单，含 .lnk 和 .url）
# ------------------------------------------------------------------------------
function Get-ExistingShortcutNames {
    $names = New-Object System.Collections.Generic.HashSet[string]
    $folders = @(
        [Environment]::GetFolderPath('Programs'),
        [Environment]::GetFolderPath('Desktop'),
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
    )
    foreach ($f in $folders) {
        if (-not (Test-Path -LiteralPath $f)) { continue }
        Get-ChildItem -LiteralPath $f -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in '.lnk', '.url' } |
            ForEach-Object { [void]$names.Add($_.BaseName.ToLowerInvariant()) }
    }
    return , $names
}

# ------------------------------------------------------------------------------
# 创建（或 -Refresh 时刷新）单个快捷方式到开始菜单。
# 返回 'created' / 'refreshed' / 'exists' / 'planned' / $null
# ------------------------------------------------------------------------------
function New-StartMenuShortcut {
    param(
        [string]$ExePath,
        [string]$Name,
        [string]$TargetFolder,
        [switch]$Refresh
    )
    $Name = Get-SafeShortcutName $Name
    if (-not $Name) { return $null }
    $lnk = Join-Path $TargetFolder "$Name.lnk"

    $action = 'Create shortcut'
    $status = 'created'

    if (Test-Path -LiteralPath $lnk) {
        $old = $null
        try { $old = $script:Wsh.CreateShortcut($lnk).TargetPath } catch { }
        if (-not $Refresh) {
            # 已存在同名：目标不同就提示一句，别默默跳过
            if ($old -and $old -ine $ExePath) {
                Write-Verbose "跳过重名: $Name (现有目标 $old)"
                $script:Duplicate++
            }
            return 'exists'
        }
        if ($old -ieq $ExePath) { return 'exists' }
        $action = 'Refresh shortcut'
        $status = 'refreshed'
    }

    if ($PSCmdlet.ShouldProcess("$ExePath", "$action -> $lnk")) {
        $sc = $script:Wsh.CreateShortcut($lnk)
        $sc.TargetPath = $ExePath
        $sc.WorkingDirectory = Split-Path -Parent $ExePath
        $sc.IconLocation = "$ExePath,0"
        $sc.Save()
        $mark = if ($status -eq 'refreshed') { '~' } else { '+' }
        $color = if ($status -eq 'refreshed') { 'Yellow' } else { 'Green' }
        Write-Host "  $mark $Name  <-  $ExePath" -ForegroundColor $color
    }
    else {
        $script:Planned++
        $script:CreatedList += [pscustomobject]@{ link = $lnk; target = $ExePath }
        return 'planned'
    }

    $script:CreatedList += [pscustomobject]@{ link = $lnk; target = $ExePath }
    return $status
}

# ------------------------------------------------------------------------------
# 在一个目录里挑最像「主程序」的 exe：
#   1) 文件名与所在文件夹同名的优先（GitKraken\GitKraken.exe）
#   2) 其次按体积挑最大的（GUI 主程序一般比辅助 exe 大）
# ------------------------------------------------------------------------------
function Select-MainExe {
    param([string]$Dir, [string]$HintName)
    $exes = @(Get-ChildItem -LiteralPath $Dir -Filter *.exe -File -ErrorAction SilentlyContinue |
            Where-Object { Test-ExeWorthShortcut $_.FullName })
    if ($exes.Count -eq 0) { return $null }
    if ($exes.Count -eq 1) { return $exes[0].FullName }

    if ($HintName) {
        $hint = [IO.Path]::GetFileNameWithoutExtension($HintName)
        $match = $exes | Where-Object { $_.BaseName -ieq $hint } | Select-Object -First 1
        if ($match) { return $match.FullName }
        $match = $exes | Where-Object { $_.BaseName -like "$hint*" -or $hint -like "$($_.BaseName)*" } |
            Sort-Object Length -Descending | Select-Object -First 1
        if ($match) { return $match.FullName }
    }
    return ($exes | Sort-Object Length -Descending | Select-Object -First 1).FullName
}

# ------------------------------------------------------------------------------
# exe 名与提示名（文件夹名 / 应用 DisplayName）是否"长得像"。
# 用来避免 C:\Program Files\Microsoft Office 里随手挑到 AppVLP.exe 这种误判。
# ------------------------------------------------------------------------------
function Test-NameSimilar {
    param([string]$Name, [string]$Hint)
    if ([string]::IsNullOrWhiteSpace($Name) -or [string]::IsNullOrWhiteSpace($Hint)) { return $false }
    $n = ($Name.ToLowerInvariant() -replace '[^a-z0-9]', '')
    $h = ($Hint.ToLowerInvariant() -replace '[^a-z0-9]', '')
    if ($n.Length -lt 3 -or $h.Length -lt 3) { return $false }
    if ($n -eq $h) { return $true }
    # 一方包含另一方（office -> officeclicktorun / gitkraken -> gitkrakenlauncher）
    if ($h.Contains($n) -or $n.Contains($h)) { return $true }
    # 共同前缀至少 4 个字符
    $max = [Math]::Min($n.Length, $h.Length)
    $i = 0
    while ($i -lt $max -and $n[$i] -eq $h[$i]) { $i++ }
    return ($i -ge 4)
}

# ------------------------------------------------------------------------------
# 深度受限地在一个应用目录里找主 exe
# ------------------------------------------------------------------------------
function Find-MainExeInTree {
    param([string]$Root, [int]$MaxDepth, [string]$HintName, [switch]$RequireHintMatch)

    # 当前层有 exe 就用当前层
    $here = Select-MainExe -Dir $Root -HintName $HintName
    if ($here) {
        if (-not $RequireHintMatch) { return $here }
        if (Test-NameSimilar -Name ([IO.Path]::GetFileNameWithoutExtension($here)) -Hint $HintName) { return $here }
    }
    if ($MaxDepth -le 0) { return $null }

    # 优先顺着 current / 最新版本号 这类子目录往下钻
    $subs = @(Get-ChildItem -LiteralPath $Root -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch '^(node_modules|resources|locales|plugins|bin|lib|libs)$' })

    # 版本号目录按数值排（不版本号的排后面），不依赖 [version] 强转，避免奇怪名字抛异常
    $versioned = @($subs | Where-Object { $_.Name -match '^\d+(\.\d+)*$' } | ForEach-Object {
            [pscustomobject]@{
                Dir = $_
                Key = (($_.Name -split '\.') | ForEach-Object { '{0:D6}' -f [int]$_ }) -join '.'
            }
        } | Sort-Object Key -Descending)

    $ordered = @()
    $ordered += $subs | Where-Object { $_.Name -ieq 'current' }
    $ordered += $versioned | ForEach-Object { $_.Dir }
    $ordered += $subs | Where-Object { $_.Name -ine 'current' -and $_.Name -notmatch '^\d+(\.\d+)*$' }

    foreach ($s in $ordered) {
        $subHint = if ($HintName) { $HintName } else { $s.Name }
        $hit = Find-MainExeInTree -Root $s.FullName -MaxDepth ($MaxDepth - 1) -HintName $subHint -RequireHintMatch:$RequireHintMatch
        if ($hit) {
            if ($RequireHintMatch -and -not (Test-NameSimilar -Name ([IO.Path]::GetFileNameWithoutExtension($hit)) -Hint $HintName)) { continue }
            return $hit
        }
    }
    return $null
}

# ------------------------------------------------------------------------------
# 主流程
# ------------------------------------------------------------------------------
$startMenu = [Environment]::GetFolderPath('Programs')
if ($PSCmdlet.ShouldProcess($startMenu, 'Create Directory')) {
    New-Item -ItemType Directory -Path $startMenu -Force | Out-Null
}

$existing = Get-ExistingShortcutNames
$script:CreatedList = @()

Write-Host "== 开始菜单快捷方式同步 ==" -ForegroundColor Cyan
Write-Host "已存在快捷方式数量: $($existing.Count)" -ForegroundColor DarkGray

# 1) 注册表 Uninstall 项（覆盖"已安装但没开始菜单快捷方式"的程序）
Write-Host "[1/4] 扫描注册表 Uninstall 项..." -ForegroundColor Cyan
$regKeys = @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
foreach ($root in $regKeys) {
    foreach ($key in Get-ItemProperty $root -ErrorAction SilentlyContinue) {
        $app = $key.DisplayName
        if ([string]::IsNullOrWhiteSpace($app)) { continue }
        if ($app -match $DisplayNameNoiseRegex) { continue }        # 驱动/运行库/SDK 之类
        if (-not $Refresh -and $existing.Contains($app.ToLowerInvariant())) { continue }
        if ($CleanVersion) {
            $app = Get-FriendlierName $app
            if ([string]::IsNullOrWhiteSpace($app)) { continue }
        }

        $exe = $null
        # 首选 DisplayIcon（通常是主程序）
        $icon = Get-RealExePath $key.DisplayIcon
        if ($icon -and (Test-ExeWorthShortcut $icon)) {
            # 让 Office / GameBar 这类「同一个工具供多个组件共用」的 exe 不进开始菜单：
            # InstallLocation 存在时，DisplayIcon 必须落在它下面，或名字与应用相关。
            $locProbe = $null
            if (-not [string]::IsNullOrWhiteSpace($key.InstallLocation)) {
                $locProbe = [Environment]::ExpandEnvironmentVariables(($key.InstallLocation.Trim().Trim('"')))
            }
            $inLoc = $locProbe -and $locProbe.Length -gt 3 -and
            $icon.StartsWith($locProbe, [StringComparison]::OrdinalIgnoreCase)
            $nameHit = Test-NameSimilar -Name ([IO.Path]::GetFileNameWithoutExtension($icon)) -Hint $app
            if (-not $locProbe -or $inLoc -or $nameHit) { $exe = $icon }
        }
        # 兜底：InstallLocation 里找主 exe（带名字提示 + 深度限制）
        if (-not $exe) {
            $locRaw = $key.InstallLocation
            if (-not [string]::IsNullOrWhiteSpace($locRaw)) {
                $loc = [Environment]::ExpandEnvironmentVariables(($locRaw.Trim().Trim('"')))
                if ((Test-Path -LiteralPath $loc -PathType Container) -and [IO.Path]::IsPathRooted($loc)) {
                    # RequireHintMatch：exe 名必须和 DisplayName 有关联，
                    # 否则 Office 这种大目录会随手抓个 AppVLP.exe 当主程序
                    $exe = Find-MainExeInTree -Root $loc -MaxDepth 2 -HintName $app -RequireHintMatch
                }
            }
        }
        if (-not $exe) { continue }

        $st = New-StartMenuShortcut -ExePath $exe -Name $app -TargetFolder $startMenu -Refresh:$Refresh
        if ($st) { [void]$existing.Add($app.ToLowerInvariant()) }
    }
}

# 2) 便携软件根目录（每个根的子目录里挑主 exe，不深挖组件目录）
$scanDirs = @()
if ($PortableRoots) { $scanDirs += $PortableRoots }
else {
    if ($env:SCOOP -and (Test-Path -LiteralPath "$env:SCOOP\apps")) { $scanDirs += "$env:SCOOP\apps" }
    $scanDirs += "$env:USERPROFILE\Portable", "$env:USERPROFILE\Apps"
}
if ($Path) { $scanDirs += $Path }

Write-Host "[2/4] 扫描便携软件目录..." -ForegroundColor Cyan
foreach ($dir in ($scanDirs | Where-Object { $_ } | Select-Object -Unique)) {
    # 支持传通配符（如 $env:SCOOP\apps\*\current）
    $expanded = @(if ($dir -match '\*|\?') { Resolve-Path $dir -ErrorAction SilentlyContinue | ForEach-Object { $_.Path } } else { $dir })
    foreach ($d in $expanded) {
        if (-not (Test-Path -LiteralPath $d -PathType Container)) { continue }
        Write-Host "  扫描: $d" -ForegroundColor DarkGray

        # 根目录里直接放着的 exe
        Get-ChildItem -LiteralPath $d -Filter *.exe -File -ErrorAction SilentlyContinue |
            Where-Object { Test-ExeWorthShortcut $_.FullName } |
            ForEach-Object {
                $b = $_.BaseName
                if (-not $Refresh -and $existing.Contains($b.ToLowerInvariant())) { return }
                $st = New-StartMenuShortcut -ExePath $_.FullName -Name $b -TargetFolder $startMenu -Refresh:$Refresh
                if ($st) { [void]$existing.Add($b.ToLowerInvariant()) }
            }

        # 每个应用子目录（scoop 的 apps\<pkg>\ 结构和普通便携目录都吃这一套）
        Get-ChildItem -LiteralPath $d -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch '^\.' } |
            ForEach-Object {
                $appDir = $_.FullName
                $main = Find-MainExeInTree -Root $appDir -MaxDepth $Depth -HintName $_.Name
                if (-not $main) { return }
                $b = [IO.Path]::GetFileNameWithoutExtension($main)
                # 名字：scoop 这类 <pkg>\current\xxx.exe 用包名更好认（7zip 而不是 7zFM）
                $display = $b
                if ((Split-Path (Split-Path $main -Parent) -Leaf) -ieq 'current') {
                    $pkg = Split-Path (Split-Path (Split-Path $main -Parent) -Parent) -Leaf
                    if ($pkg) { $display = $pkg }
                }
                if (-not $Refresh -and $existing.Contains($display.ToLowerInvariant())) { return }
                $st = New-StartMenuShortcut -ExePath $main -Name $display -TargetFolder $startMenu -Refresh:$Refresh
                if ($st) { [void]$existing.Add($display.ToLowerInvariant()) }
            }
    }
}

# 3) 清理失效快捷方式（-Prune，只动 manifest 里记录的）
$manifest = @(Read-Manifest)
if ($Prune) {
    Write-Host "[3/4] 清理失效快捷方式（只处理本脚本建的）..." -ForegroundColor Cyan
    $kept = @()
    $pruned = 0
    foreach ($entry in $manifest) {
        if (-not $entry -or -not $entry.link) { continue }
        $lnk = [string]$entry.link
        $target = [string]$entry.target

        if (-not (Test-Path -LiteralPath $lnk)) { continue }        # 条目不在了，顺手弃掉
        $alive = $false
        if ($target) {
            $probe = [Environment]::ExpandEnvironmentVariables($target)
            $alive = Test-Path -LiteralPath $probe
        }
        if ($alive) { $kept += $entry }
        else {
            if ($PSCmdlet.ShouldProcess($lnk, 'Remove dead shortcut')) {
                Remove-Item -LiteralPath $lnk -Force -ErrorAction SilentlyContinue
                Write-Host "  - 已删除失效: $([IO.Path]::GetFileNameWithoutExtension($lnk)) (target: $target)" -ForegroundColor Yellow
            }
            $pruned++
        }
    }
    if (-not $WhatIfPreference) { Write-Manifest $kept }
    Write-Host "清理失效快捷方式: $pruned" -ForegroundColor Green
}
else {
    Write-Host "[3/4] 跳过清理（加 -Prune 才会删）" -ForegroundColor DarkGray
}

# 合并 manifest（本次新建 + 历史保留）
if ($script:CreatedList.Count -gt 0) {
    $merged = @($manifest) + @($script:CreatedList)
    Write-Manifest $merged
}

# 4) 汇总 + 可选刷新索引
Write-Host "[4/4] 完成" -ForegroundColor Cyan
# 用无条件执行块：-WhatIf 演练时也照样打印汇总（ShouldProcess 在 WhatIf 下会返回 false）
& {
    $createdCount = $script:CreatedList.Count
    $label = if ($WhatIfPreference) { '演练：将会新建/刷新快捷方式' } else { '本次新建/刷新快捷方式' }
    Write-Host "$label : $createdCount" -ForegroundColor Green
    if ($WhatIfPreference) {
        Write-Host "（-WhatIf 演练，以上条目并未真的写入）" -ForegroundColor Yellow
    }
    elseif ($script:Duplicate -gt 0) {
        Write-Host "已存在同名快捷方式、目标是别的程序: $($script:Duplicate) 个（加 -Verbose 看名字）" -ForegroundColor DarkYellow
    }
    if ($script:CreatedList.Count -eq 0 -and -not $WhatIfPreference) {
        Write-Host "（没有需要新建的，CmdPal 应该都能搜到了）" -ForegroundColor Yellow
    }

    if ($Reload) {
        if ($PSCmdlet.ShouldProcess('explorer + PowerToys', 'Restart')) {
            Write-Host "重启 explorer 和 PowerToys 以刷新 CmdPal 索引..." -ForegroundColor Cyan

            # explorer：重启它会顺带把开始菜单刷新一遍
            try {
                Get-Process -Name explorer -ErrorAction SilentlyContinue | ForEach-Object { $_.Kill() }
                Start-Sleep -Milliseconds 1200
                if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
                Write-Host "  explorer 已重启" -ForegroundColor Green
            }
            catch {
                Write-Host "  explorer 重启失败（可能需要管理员）：$($_.Exception.Message)" -ForegroundColor Yellow
            }

            # PowerToys：必须确认它真的退了再拉起，否则会说谎
            $pt = "$env:LOCALAPPDATA\PowerToys\PowerToys.exe"
            $ptProc = Get-Process -Name PowerToys -ErrorAction SilentlyContinue | Select-Object -First 1
            $ptOldStart = if ($ptProc) { $ptProc.StartTime } else { $null }

            if ($ptProc) {
                try { $ptProc.Kill() } catch { }
                # 最多等 8 秒，确认真的退出
                $waited = 0
                while ((Get-Process -Name PowerToys -ErrorAction SilentlyContinue) -and $waited -lt 8000) {
                    Start-Sleep -Milliseconds 400
                    $waited += 400
                }
            }

            $stillAlive = [bool](Get-Process -Name PowerToys -ErrorAction SilentlyContinue)
            if ($stillAlive) {
                Write-Host "  PowerToys 没能退出（多半是被保护/需要管理员）。" -ForegroundColor Yellow
                Write-Host "  请手动右键托盘图标退出再打开，或直接重启 CmdPal：" -ForegroundColor Yellow
                Write-Host "    Get-Process PowerToys.PowerLauncher | Stop-Process -Force" -ForegroundColor DarkGray
            }
            elseif (-not (Test-Path -LiteralPath $pt)) {
                Write-Host "  没找到 PowerToys.exe，请手动打开它" -ForegroundColor Yellow
            }
            else {
                Start-Process $pt
                Start-Sleep -Seconds 2
                $newProc = Get-Process -Name PowerToys -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($newProc -and (-not $ptOldStart -or $newProc.StartTime -ne $ptOldStart)) {
                    Write-Host "  PowerToys 已重启（新进程 $($newProc.Id)）" -ForegroundColor Green
                }
                else {
                    Write-Host "  PowerToys 已启动但没能确认新进程，请检查托盘图标" -ForegroundColor Yellow
                }
            }
        }
    }
    else {
        Write-Host "提示: 加 -Reload 可自动重启 explorer + PowerToys 刷新 CmdPal 索引。" -ForegroundColor DarkGray
    }
}
