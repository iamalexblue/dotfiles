# ==============================================================================
# Add-StartMenuShortcuts.ps1
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
#     sm-update                          # 扫描默认目录 + 注册表 Uninstall 项
#     sm-update -Path D:\Apps            # 额外扫描自定义便携目录
#     sm-update -CleanVersion            # 去掉名称里的版本号（WPS Office (12.1.0.28022) -> WPS Office）
#     sm-update -Refresh                 # 已有快捷方式也重新指向最新 exe（target 变了就刷新）
#     sm-update -Prune                   # 删除目标 exe 已不存在的失效快捷方式
#     sm-update -WhatIf                  # 演练模式，只看会做什么，不实际执行
#     sm-update -Path "$env:USERPROFILE\scoop\apps\*\current"   # scoop 应用（current 子目录）
# ==============================================================================

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    # 额外要扫描的便携目录（可传多个）。
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Path,

    # 便携软件根目录：每个根下面「直接子目录」里的主 exe 会被考虑。
    # 按需改成你自己的目录。
    [string[]]$PortableRoots = @(
        "$env:USERPROFILE\Portable",
        "$env:USERPROFILE\Apps",
        "$env:USERPROFILE\scoop\apps"
    ),

    # 已有同名快捷方式时也重新指向找到的最新 exe（target 不一致则刷新）。
    [switch]$Refresh,

    # 删除目标 exe 已不存在的失效快捷方式（清理残留）。
    [switch]$Prune,

    # 去掉应用名里的版本号（只对新建/刷新时生效）。
    [switch]$CleanVersion,

    # 显示用法帮助（不执行任何操作）。
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
   sm-update                         扫描注册表 Uninstall 项 + 便携目录，补建快捷方式
   sm-update -Path <目录>            额外扫描自定义便携目录（可多个）

 参数：
   -PortableRoots <数组>   便携根目录（默认 ~\Portable, ~\Apps, ~\scoop\apps）
   -CleanVersion           去掉应用名里的版本号（WPS Office (12.1.0.28022) -> WPS Office）
   -Refresh                已有快捷方式但 target 变了就重新指向（改写，建议先 -WhatIf）
   -Prune                  删除目标 exe 已消失的失效快捷方式（删除，建议先 -WhatIf）
   -WhatIf                 演练模式：只列出会做什么，不实际执行
   -Help                  显示本帮助

 组合示例：
   sm-update -CleanVersion                        # 常规 + 去版本号
   sm-update -Path "$env:USERPROFILE\scoop\apps\*\current"   # 补扫 scoop 应用
   sm-update -WhatIf -Prune -CleanVersion         # 先预览所有改动
   sm-update -Prune                               # 清理失效快捷方式

 安全提示：
   - 脚本只【读】注册表 Uninstall 项，从不写注册表；全部改动只在开始菜单文件夹。
   - 正式跑 -Prune / -Refresh 前，务必先加 -WhatIf 预览。
   - 运行后重启 explorer + 重启 PowerToys 刷新 CmdPal 索引。
'@
    $helpText | Write-Verbose
    Write-Host $helpText
    exit
}

# 文件名黑名单（安装器 / 卸载器 / 运行库 / 通用工具，绝不生成快捷方式）
$ExeNameBlacklist = @(
    'uninstall', 'unins000', 'unins001', 'setup', 'install', 'installer',
    'vc_redist', 'vcredist', 'dotnet', 'dotnet-install', 'msiexec',
    'npm', 'npx', 'yarn', 'pnpm', 'nodevars', 'winsw', 'bash', 'sh', 'cmd',
    'powershell', 'pwsh', 'cmdproxy', 'conhost', 'rdpclip', 'notepad'
) | ForEach-Object { $_.ToLowerInvariant() }

# 只要文件名里出现这些片段就跳过（辅助进程 / 组件）
$ExeNameDenySubstring = @(
    'crashreport', 'crashsender', 'creporter', 'elevat', 'uninstall',
    'setup', 'installer', 'updater', 'helper', 'daemon', 'proxy', 'shim',
    'diagnostic', 'tunnel', 'devcon', 'tapinstall', 'certmgr',
    'notification', 'host_client', 'host-prep', 'guest', 'sandbox',
    'vsce-sign', 'conpty', 'inno_updater', 'service', 'agent'
) | ForEach-Object { $_.ToLowerInvariant() }

# 路径黑名单片段（跑到这些目录里的一律是内部组件）
$PathDenySubstring = @(
    'node_modules', 'builtin-plugins', '.unpacked', '\resources\',
    '\components\', '\driver\', '\Installer\', '\installer\',
    '\Assets\Utilities\', '\bin\', '\tools\inno', '\Redistributables\',
    '\Common Files\', '\uninstall\', '\dist\'
) | ForEach-Object { $_.ToLowerInvariant() }

# ------------------------------------------------------------------------------
# 判断一个 exe 是否值得生成快捷方式。
# ------------------------------------------------------------------------------
function Test-ExeWorthShortcut {
    param([string]$ExePath)
    $base = [IO.Path]::GetFileNameWithoutExtension($ExePath).ToLowerInvariant()
    $pathL = $ExePath.ToLowerInvariant()

    if ([string]::IsNullOrWhiteSpace($base)) { return $false }
    if ($ExeNameBlacklist -contains $base)   { return $false }
    foreach ($s in $ExeNameDenySubstring) { if ($base.Contains($s)) { return $false } }
    foreach ($s in $PathDenySubstring)    { if ($pathL.Contains($s)) { return $false } }
    return $true
}

# ------------------------------------------------------------------------------
# 把注册表 DisplayIcon 之类的原始字符串解析成真实可用的 exe 路径：
#   去掉图标索引后缀 ",N"、去掉首尾引号、展开环境变量、转为绝对路径。
# 解析失败或不存在返回 $null。
# ------------------------------------------------------------------------------
function Get-RealExePath {
    param([string]$Raw)
    if ([string]::IsNullOrWhiteSpace($Raw)) { return $null }
    $p = $Raw.Trim().Trim('"')
    # 去掉图标索引：C:\x\app.exe,0
    if ($p -match '^(.*\.(exe|lnk))\s*,\s*\d+\s*$') { $p = $Matches[1] }
    else { $p = $p -split ',' | Select-Object -First 1 }
    $p = [Environment]::ExpandEnvironmentVariables($p)
    try { $p = [IO.Path]::GetFullPath($p) } catch { return $null }
    if (-not (Test-Path -LiteralPath $p)) { return $null }
    return $p
}

# ------------------------------------------------------------------------------
# 清洗快捷方式名：去掉控制字符(null) 与 Windows 文件名非法字符 `<>:"/\|?*`。
# ------------------------------------------------------------------------------
function Get-SafeShortcutName {
    param([string]$Name)
    $clean = $Name -replace '[<>:"/\\|?*\p{Cc}]', ' ' -replace '\s+', ' '
    $clean = $clean.Trim()
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
# 创建（或 -Refresh 时刷新）单个快捷方式到开始菜单。
# ------------------------------------------------------------------------------
function New-StartMenuShortcut {
    param(
        [string]$ExePath,
        [string]$Name,
        [string]$TargetFolder,
        [switch]$Refresh
    )
    $Name = Get-SafeShortcutName $Name
    if (-not $Name) { return }
    $lnk = Join-Path $TargetFolder "$Name.lnk"

    $action = 'Create shortcut'
    if (Test-Path -LiteralPath $lnk) {
        if (-not $Refresh) { return }
        $shell = New-Object -ComObject WScript.Shell
        $old = $shell.CreateShortcut($lnk).TargetPath
        if ($old -ieq $ExePath) { return }
        $action = 'Refresh shortcut'
    }

    if ($PSCmdlet.ShouldProcess("$ExePath", "$action -> $lnk")) {
        $shell = New-Object -ComObject WScript.Shell
        $sc = $shell.CreateShortcut($lnk)
        $sc.TargetPath = $ExePath
        $sc.WorkingDirectory = Split-Path -Parent $ExePath
        $sc.IconLocation = "$ExePath,0"
        $sc.Save()
        $mark = if ($action -eq 'Refresh shortcut') { '~' } else { '+' }
        Write-Host "  $mark $Name  <-  $ExePath" -ForegroundColor Green
    }
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
        Get-ChildItem -LiteralPath $f -Include *.lnk, *.url -Recurse -File -ErrorAction SilentlyContinue |
            ForEach-Object { [void]$names.Add($_.BaseName.ToLowerInvariant()) }
    }
    Write-Output -NoEnumerate $names
}

# ------------------------------------------------------------------------------
# 主流程
# ------------------------------------------------------------------------------
Write-Host "== 开始菜单快捷方式同步 ==" -ForegroundColor Cyan

$startMenu = [Environment]::GetFolderPath('Programs')
New-Item -ItemType Directory -Path $startMenu -Force | Out-Null
$existing = Get-ExistingShortcutNames
Write-Host "已存在快捷方式数量: $($existing.Count)" -ForegroundColor DarkGray
$created = 0

# 1) 注册表 Uninstall 项（覆盖"已安装但没开始菜单快捷方式"的程序）
Write-Host "[1/3] 扫描注册表 Uninstall 项..." -ForegroundColor Cyan
foreach ($root in @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)) {
    foreach ($key in Get-ItemProperty $root -ErrorAction SilentlyContinue) {
        $app = $key.DisplayName
        if ([string]::IsNullOrWhiteSpace($app)) { continue }
        if (-not $Refresh -and $existing.Contains($app.ToLowerInvariant())) { continue }
        if ($CleanVersion) {
            $app = Get-FriendlierName $app
            if ([string]::IsNullOrWhiteSpace($app)) { continue }
        }

        $exe = $null
        # 首选 DisplayIcon（通常是主程序），解析掉图标索引/引号/环境变量
        $icon = Get-RealExePath $key.DisplayIcon
        if ($icon -and (Test-Path -LiteralPath $icon) -and (Test-ExeWorthShortcut $icon) -and
            (Split-Path -Leaf $icon) -imatch '\.(exe|lnk)$') {
            $exe = $icon
        }
        # 兜底：InstallLocation 的直接子目录里找最大 exe（只找一层，避开组件）
        if (-not $exe) {
            $locRaw = $key.InstallLocation
            if (-not [string]::IsNullOrWhiteSpace($locRaw)) {
                $loc = [Environment]::ExpandEnvironmentVariables(($locRaw.Trim().Trim('"')))
                if (Test-Path -LiteralPath $loc -PathType Container) {
                    $candidate = Get-ChildItem -LiteralPath $loc -Filter *.exe -File -ErrorAction SilentlyContinue |
                        Where-Object { Test-ExeWorthShortcut $_.FullName } |
                        Sort-Object Length -Descending |
                        Select-Object -First 1
                    if ($candidate) { $exe = $candidate.FullName }
                }
            }
        }
        if (-not $exe) { continue }

        New-StartMenuShortcut -ExePath $exe -Name $app -TargetFolder $startMenu -Refresh:$Refresh
        [void]$existing.Add($app.ToLowerInvariant())
        if (-not $Refresh -or -not (Test-Path -LiteralPath (Join-Path $startMenu "$(Get-SafeShortcutName $app).lnk"))) {
            $created++
        }
    }
}

# 2) 便携软件根目录（每个根的直接子目录里挑主 exe，不深挖组件目录）
Write-Host "[2/3] 扫描便携软件目录..." -ForegroundColor Cyan
$scanDirs = @($PortableRoots) + @($Path | Where-Object { $_ })
foreach ($dir in ($scanDirs | Select-Object -Unique)) {
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { continue }
    Write-Host "  扫描: $dir" -ForegroundColor DarkGray

    # 根目录本身
    Get-ChildItem -LiteralPath $dir -Filter *.exe -File -ErrorAction SilentlyContinue |
        Where-Object { Test-ExeWorthShortcut $_.FullName } |
        ForEach-Object {
            $b = $_.BaseName
            if (-not $Refresh -and $existing.Contains($b.ToLowerInvariant())) { return }
            New-StartMenuShortcut -ExePath $_.FullName -Name $b -TargetFolder $startMenu -Refresh:$Refresh
            [void]$existing.Add($b.ToLowerInvariant())
        }

    # 每个应用的子目录（只取该子目录直接存放的主 exe）
    Get-ChildItem -LiteralPath $dir -Directory -ErrorAction SilentlyContinue |
        ForEach-Object {
            $appDir = $_.FullName
            Get-ChildItem -LiteralPath $appDir -Filter *.exe -File -ErrorAction SilentlyContinue |
                Where-Object { Test-ExeWorthShortcut $_.FullName } |
                Sort-Object Length -Descending |
                Select-Object -First 1 |
                ForEach-Object {
                    $b = $_.BaseName
                    if (-not $Refresh -and $existing.Contains($b.ToLowerInvariant())) { return }
                    New-StartMenuShortcut -ExePath $_.FullName -Name $b -TargetFolder $startMenu -Refresh:$Refresh
                    [void]$existing.Add($b.ToLowerInvariant())
                }
        }
}

# 3) 清理失效快捷方式（-Prune）
if ($Prune) {
    Write-Host "[3/4] 清理失效快捷方式..." -ForegroundColor Cyan
    $pruned = 0
    Get-ChildItem -LiteralPath $startMenu -Filter *.lnk -Recurse -File -ErrorAction SilentlyContinue |
        ForEach-Object {
            $target = $null
            try { $target = (New-Object -ComObject WScript.Shell).CreateShortcut($_.FullName).TargetPath } catch { }

            # 保守判定：只可能是"真失效"才删，绝不误删系统/shell/命名空间快捷方式
            $isDead = $false
            if ([string]::IsNullOrWhiteSpace($target)) {
                # 空 TargetPath = CLSID/命名空间等系统快捷方式，保留
                $isDead = $false
            }
            else {
                $target = [Environment]::ExpandEnvironmentVariables($target)
                # 若以引号开头则取引号内路径（去掉可执行参数），否则用完整路径
                $probe = $target
                if ($probe -match '^"[^"]+"') { $probe = $Matches[0].Trim('"') }
                # 系统/命名空间/裸名（PATH 解析）一律保留
                if ($probe -match '^(shell:|::|\{|[a-zA-Z]:\\Windows)' -or -not $probe.Contains('\')) {
                    $isDead = $false
                }
                else {
                    $isDead = -not (Test-Path -LiteralPath $probe)
                }
            }

            if ($isDead) {
                if ($PSCmdlet.ShouldProcess($_.FullName, 'Remove dead shortcut')) {
                    Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
                    $pruned++
                    Write-Host "  - 已删除失效: $($_.BaseName)" -ForegroundColor Yellow
                }
            }
        }
    Write-Host "清理失效快捷方式: $pruned" -ForegroundColor Green
}

# 4) 汇总
Write-Host "[done] 完成" -ForegroundColor Cyan
if ($PSCmdlet.ShouldProcess('', 'Summary')) {
    Write-Host "本次新建/刷新快捷方式: $created" -ForegroundColor Green
    if ($created -eq 0) { Write-Host "（没有需要新建的，CmdPal 应该都能搜到了）" -ForegroundColor Yellow }
    Write-Host "提示: 运行后请重启 explorer + 重启 PowerToys 刷新 CmdPal 索引。" -ForegroundColor DarkGray
    Write-Host "      sm-update -Prune 可清理失效快捷方式；-CleanVersion 可去掉版本号；-Refresh 可刷新 target。" -ForegroundColor DarkGray
}