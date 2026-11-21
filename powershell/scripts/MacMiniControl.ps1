<#
.SYNOPSIS
    Mac mini (deskflow 主机) 控制脚本 —— 唤醒显示器 / 重启 deskflow / 体检

.DESCRIPTION
    所有远端动作通过【一次】 ssh 连接完成（bash -s 走 stdin），
    避免原来每条命令弹一次密码。UID、LaunchAgent 标签都动态探测，
    不再硬编码 gui/501。

    重点修复：
      · gui/501 硬编码  -> 用 id -u 动态取
      · 2>/dev/null 吞错 -> 错误原样打印
      · Service 标签写死 -> 扫 ~/Library/LaunchAgents 找 deskflow 相关 plist
      · 找不到服务就放弃 -> 回退到 open -a Deskflow
      · 无 GUI 会话误判   -> 先查 /dev/console 属主

.PARAMETER Action
    wake      唤醒显示器 + 重启 deskflow（默认）
    sleep     让显示器睡眠（保持系统唤醒）
    status    只查看当前状态，不改动
    doctor    完整体检，排障用（把所有相关信息都打出来）
    deskflow  只重启 deskflow，不碰显示器

.EXAMPLE
    .\MacMiniControl.ps1 -Action wake
    .\MacMiniControl.ps1 -Action doctor
#>

[CmdletBinding()]
param(
    [ValidateSet('wake', 'sleep', 'status', 'doctor', 'deskflow')]
    [string]$Action = 'wake',

    # ssh config 里的 Host 别名
    [string]$SshHost = 'mac-mini',

    # 唤醒时 caffeinate 持续秒数
    [ValidateRange(1, 60)]
    [int]$WakeSeconds = 2,

    # 连不上时等多久
    [ValidateRange(5, 120)]
    [int]$Timeout = 15,

    # 找不到 LaunchAgent 时也强行尝试 open -a Deskflow
    [switch]$Force,

    # 只打印将要发到远端的脚本，不真的连接（排障用）
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# ------------------------------------------------------------------------------
# 远端脚本构建：每一块都尽量自愈，任何一步失败都不中断后续检查
# ------------------------------------------------------------------------------
function Get-RemoteScript {
    param([string]$Action, [int]$WakeSeconds, [switch]$Force)

    # 公共前置：探测 uid / 控制台属主 / 找 deskflow 的 plist
    $prelude = @'
set -u
ME=$(whoami)
UID_NUM=$(id -u)
CONSOLE_USER=$(stat -f %Su /dev/console 2>/dev/null || echo unknown)

echo "### BASIC"
echo "user=$ME"
echo "uid=$UID_NUM"
echo "console_user=$CONSOLE_USER"
echo "sw_vers=$(sw_vers -productVersion 2>/dev/null || echo unknown)"

# 找 deskflow 的 LaunchAgent：优先 com.deskflow.*，其次任何名字带 deskflow 的。
# 注意：macOS / Deskflow 升级后常把 plist 改名成 *.plist.disabled 来停用，
# 这时 LABEL 拿不到，但必须把 PLIST_DISABLED 报出来（否则只看到"没有 plist"）。
LABEL=""
PLIST=""
PLIST_DISABLED=""
for f in "$HOME"/Library/LaunchAgents/*.plist "$HOME"/Library/LaunchAgents/*.plist.disabled; do
  [ -e "$f" ] || continue
  b=$(basename "$f")
  case "$b" in
    *[Dd]eskflow*|*DESKFLOW*)
      case "$b" in
        *.plist)          LABEL="${b%.plist}"; PLIST="$f" ;;
        *.plist.disabled) PLIST_DISABLED="$f" ;;
      esac
      ;;
  esac
done

# Deskflow 1.27+ 用"应用作业"方式启动（application.<bundle-id>.<...>），不是 LaunchAgent。
APP_LABEL=$(launchctl list 2>/dev/null | awk '$3 ~ /deskflow/ && $3 ~ /^application\./ {print $3; exit}')
APP_PID=$(launchctl list 2>/dev/null | awk '$3 ~ /deskflow/ && $3 ~ /^application\./ {print $1; exit}')

echo "### LAUNCHAGENT"
LOADED=no
if [ -n "$LABEL" ]; then
  echo "label=$LABEL"
  echo "plist=$PLIST"
  # 校验 domain 里是否真的注册了
  if launchctl print "gui/$UID_NUM/$LABEL" >/dev/null 2>&1; then
    LOADED=yes
  fi
  echo "loaded=$LOADED"
elif [ -n "$PLIST_DISABLED" ]; then
  echo "label="
  echo "plist="
  echo "loaded=no"
  echo "plist_disabled=$PLIST_DISABLED"
  echo "info=LaunchAgent 已被禁用（*.plist.disabled），Deskflow 1.27+ 改用应用式启动"
else
  echo "label="
  echo "plist="
  echo "loaded=no"
  echo "hint=~/Library/LaunchAgents 里没有 deskflow 相关 plist"
fi

if [ -n "$APP_LABEL" ]; then
  echo "app_label=$APP_LABEL"
  echo "app_pid=$APP_PID"
fi

# GUI domain 是否存在（没人在图形界面登录时不存在）
if launchctl print "gui/$UID_NUM" >/dev/null 2>&1; then
  echo "gui_domain=yes"
else
  echo "gui_domain=no"
  echo "hint=gui 域不存在：多半没人图形登录（Mac 卡在登录界面/重启后未登录）"
fi
'@

    # 注意：全部用单引号 here-string，避免 PowerShell 抢先展开 $LABEL/$UID_NUM 等 bash 变量。
    # 需要注入的值一律用 __占位符__ 之后 Replace。
    $wakeBlock = @'
echo "### WAKE"
if command -v caffeinate >/dev/null 2>&1; then
  caffeinate -u -t __WAKE__ 2>&1 | sed 's/^/  /'
  echo "ok=caffeinate 完成(__WAKE__ s)"
else
  echo "warn=没有 caffeinate"
fi
'@

    $sleepBlock = @'
echo "### SLEEP"
if command -v pmset >/dev/null 2>&1; then
  pmset displaysleepnow 2>&1 | sed 's/^/  /'
  echo "ok=已请求显示器睡眠"
else
  echo "warn=没有 pmset"
fi
'@

    $deskflowBlock = @'
echo "### DESKFLOW"
RESTARTED=no

# 找 app 路径
APP=""
for cand in "/Applications/Deskflow.app" "$HOME/Applications/Deskflow.app" "/Applications/Deskflow Client.app"; do
  if [ -d "$cand" ]; then APP="$cand"; break; fi
done

# 路线 A：老的 LaunchAgent（Deskflow <= 1.26 或手动装的）
if [ -n "$LABEL" ] && [ "$LOADED" = "yes" ]; then
  echo "info=走 LaunchAgent: $LABEL"
  if launchctl kickstart -k "gui/$UID_NUM/$LABEL" >/dev/null 2>&1; then
    RESTARTED=yes
    echo "ok=kickstart $LABEL"
  else
    echo "warn=kickstart 失败，转 app 方式"
  fi
fi

# 路线 B：Deskflow 1.27+ 的应用作业（application.<bundle-id>.*）
# 直接 kickstart/restart 这个 application job
if [ "$RESTARTED" = "no" ] && [ -n "$APP_LABEL" ]; then
  echo "info=走应用作业: $APP_LABEL"
  if launchctl kickstart -k "gui/$UID_NUM/$APP_LABEL" >/dev/null 2>&1; then
    RESTARTED=yes
    echo "ok=kickstart $APP_LABEL"
  else
    echo "warn=kickstart 应用作业失败，转 kill+open"
  fi
fi

# 路线 C：launchctl submit 到 GUI 域（Deskflow 1.27 上的唯一可靠办法）
#
# 为什么 open -a 不行：SSH 会话没有图形上下文，GUI app 一启动就退出。
# 实测 open -a 和 sudo launchctl asuser + open 都失败。
# 而 launchctl submit 把进程登记进 launchd 的 login 域，
# 它自然就获得了 GUI session，能正常跑起来。
if [ "$RESTARTED" = "no" ]; then
  # 先清掉旧进程
  PIDS=$(pgrep -x Deskflow 2>/dev/null)
  if [ -n "$PIDS" ]; then
    echo "info=结束旧进程: $PIDS"
    # shellcheck disable=SC2086
    kill $PIDS 2>/dev/null
    i=0
    while pgrep -x Deskflow >/dev/null 2>&1 && [ $i -lt 30 ]; do
      sleep 0.2; i=$((i+1))
    done
    if pgrep -x Deskflow >/dev/null 2>&1; then
      echo "info=优雅退出超时，强杀"
      pkill -9 -x Deskflow 2>/dev/null
      sleep 1
    fi
  fi
  # core 子进程也要清，否则它占着 IPC 端口
  pkill -x deskflow-core 2>/dev/null
  sleep 1

  if [ -n "$APP" ]; then
    BIN="$APP/Contents/MacOS/Deskflow"
    if [ -x "$BIN" ]; then
      echo "info=launchctl submit -> gui/$UID_NUM"
      # 先移除上次 submit 的残留
      launchctl remove com.deskflow.manual >/dev/null 2>&1
      launchctl submit -l com.deskflow.manual -- "$BIN" 2>&1 | sed 's/^/  /'
      sleep 4
      if pgrep -x Deskflow >/dev/null 2>&1; then
        RESTARTED=yes
        echo "ok=已通过 launchctl submit 启动"
      else
        echo "warn=submit 后进程仍未出现"
      fi
    else
      echo "warn=找不到可执行文件: $BIN"
    fi
  else
    echo "warn=/Applications 下没找到 Deskflow.app"
  fi
fi

echo "restarted=$RESTARTED"
'@

    # 状态 / 结果汇总
    $reportBlock = @'
echo "### RESULT"
if pgrep -x Deskflow >/dev/null 2>&1; then
  echo "deskflow=running"
  echo "pids=$(pgrep -x Deskflow | tr '\n' ' ')"
else
  echo "deskflow=stopped"
fi

# 显示器当前是否点亮。1=on 0=off。
# 注意：Apple Silicon 上 pmset -g powerstate IODisplayWrangler 常直接失败，
# 输出 "Internal failure..."，此时 awk 会抓到最后一个词冒充答案。必须校验。
DISP=""
DISP_RAW=$(pmset -g powerstate IODisplayWrangler 2>/dev/null)
case "$DISP_RAW" in
  ''|*failure*|*Failed*|*not\ found*) DISP="unknown" ;;
  *)
    # 数据行最后一列才是 state
    DISP=$(printf '%s\n' "$DISP_RAW" | awk 'NF && $0 !~ /Driver ID/ {v=$NF} END{print v}')
    case "$DISP" in
      ''|*[!0-9]*) DISP="unknown" ;;
    esac
    ;;
esac
[ -z "$DISP" ] && DISP="unknown"
echo "display=$DISP"

echo "### END"
'@

    $doctorExtra = @'
echo "### DOCTOR"
echo "--- launchagents (deskflow) ---"
ls -1 "$HOME/Library/LaunchAgents" 2>/dev/null | grep -i deskflow || echo "  (none)"
echo "--- launchctl list (deskflow) ---"
launchctl list 2>/dev/null | grep -i deskflow || echo "  (none)"
echo "--- processes ---"
pgrep -lf -i deskflow 2>/dev/null || echo "  (none)"
echo "--- console session ---"
stat -f "console_user=%Su  tty=%Sr" /dev/console 2>/dev/null
who 2>/dev/null | sed 's/^/  /'
echo "--- displays ---"
pmset -g powerstate IODisplayWrangler 2>/dev/null | sed 's/^/  /'
echo "--- app present ---"
for cand in "/Applications/Deskflow.app" "$HOME/Applications/Deskflow.app"; do
  [ -d "$cand" ] && echo "  $cand (yes)"
done
echo "--- plist content (if any) ---"
[ -n "$PLIST" ] && [ -f "$PLIST" ] && sed 's/^/  /' "$PLIST"
echo "--- Deskflow version ---"
for cand in "/Applications/Deskflow.app/Contents/Info.plist"; do
  [ -f "$cand" ] && /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$cand" 2>/dev/null | sed 's/^/  version=/'
done
'@

    # 组装
    $parts = @($prelude)
    switch ($Action) {
        'wake' { $parts += $wakeBlock; $parts += $deskflowBlock; $parts += $reportBlock }
        'sleep' { $parts += $sleepBlock }
        'deskflow' { $parts += $deskflowBlock; $parts += $reportBlock }
        'status' { $parts += $reportBlock }
        'doctor' { $parts += $doctorExtra; $parts += $reportBlock }
    }

    $script = ($parts -join "`n")

    # 注入参数（此时才做替换，避免被 PowerShell 提前展开）
    $script = $script.Replace('__WAKE__', [string]$WakeSeconds)

    # -Force：即使 pgrep 看到 Deskflow 也强行走一遍 open
    if ($Force) {
        $script = $script.Replace(
            'if ! pgrep -x Deskflow >/dev/null 2>&1; then',
            'if true; then')
    }

    return $script
}

# ------------------------------------------------------------------------------
# 把远端 Key=Value 输出渲染成好读的形式
# ------------------------------------------------------------------------------
function Format-RemoteOutput {
    param([string[]]$Lines)

    $problems = @()
    foreach ($line in $Lines) {
        $l = $line.TrimEnd()

        if ($l -match '^###\s+(.+)$') {
            Write-Host ''
            Write-Host "-- $($Matches[1]) " -ForegroundColor Cyan -NoNewline
            Write-Host ('-' * [Math]::Max(1, 40 - $Matches[1].Length)) -ForegroundColor DarkGray
            continue
        }

        if ($l -match '^(ok|warn|info|hint)\s*=\s*(.*)$') {
            $kind = $Matches[1]; $msg = $Matches[2]
            switch ($kind) {
                'ok'   { Write-Host "  OK   " -ForegroundColor Green -NoNewline; Write-Host $msg }
                'warn' { Write-Host "  WARN " -ForegroundColor Yellow -NoNewline; Write-Host $msg; $problems += $msg }
                'info' { Write-Host "  INFO " -ForegroundColor DarkCyan -NoNewline; Write-Host $msg }
                'hint' { Write-Host "  HINT " -ForegroundColor DarkYellow -NoNewline; Write-Host $msg; $problems += $msg }
            }
            continue
        }

        if ($l -match '^(label|plist|plist_disabled|loaded|app_label|app_pid|gui_domain|uid|user|console_user|sw_vers|deskflow|pids|display|restarted)\s*=\s*(.*)$') {
            $k = $Matches[1]; $v = $Matches[2]
            $color = 'Gray'
            if ($k -eq 'loaded' -and $v -eq 'yes') { $color = 'Green' }
            if ($k -eq 'loaded' -and $v -eq 'no') { $color = 'DarkGray' }
            if ($k -eq 'restarted' -and $v -eq 'yes') { $color = 'Green' }
            if ($k -eq 'restarted' -and $v -eq 'no') { $color = 'Yellow' }
            if ($k -eq 'deskflow' -and $v -eq 'running') { $color = 'Green' }
            if ($k -eq 'deskflow' -and $v -eq 'stopped') { $color = 'Red' }
            if ($k -eq 'gui_domain' -and $v -eq 'no') { $color = 'Red' }
            if ($k -eq 'display' -and $v -eq 'unknown') { $color = 'DarkGray' }
            if ($k -eq 'plist_disabled') { $color = 'DarkYellow' }
            Write-Host ("  {0,-15} {1}" -f $k, $v) -ForegroundColor $color
            continue
        }

        Write-Host "  $l" -ForegroundColor DarkGray
    }

    return $problems
}

# ------------------------------------------------------------------------------
# 执行
# ------------------------------------------------------------------------------
if ($Action -eq 'doctor') {
    Write-Host "== Mac mini 体检 ($SshHost) ==" -ForegroundColor Cyan
}
else {
    Write-Host "== Mac mini: $Action ==" -ForegroundColor Cyan
}

$remote = Get-RemoteScript -Action $Action -WakeSeconds $WakeSeconds -Force:$Force

if ($DryRun) {
    Write-Host "===== 将要发送到 $SshHost 的脚本 =====" -ForegroundColor DarkGray
    Write-Host $remote
    Write-Host "===== 结束 =====" -ForegroundColor DarkGray
    exit 0
}

# 关键：整段脚本一次性发给远端，只有一次 ssh 连接 => 只问一次密码 / 只授权一次。
#
# 为什么用 base64 而不是重定向 stdin：
#   如果 ssh 的 stdin 被重定向（管道/文件），它就没法用 stdin 读密码，
#   又因为没有 tty 而不会弹提示，只能干等直到超时（实测卡死）。
#   把脚本 base64 编码后塞进命令行参数，stdin 就留给 ssh 自己用，
#   密码提示 / 授权弹窗才能正常工作。
$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($remote))
$remoteCmd = "echo $b64 | base64 -d | bash"

$sshArgs = @(
    '-o', "ConnectTimeout=$Timeout",
    '-o', 'ServerAliveInterval=5',
    $SshHost,
    $remoteCmd
)

try {
    # 直接调用 ssh.exe，让它的 stdin/stdout 直连控制台 —— 密码提示和授权弹窗才能工作。
    # 2>&1 把 stderr 合进来，远端的 warn 才看得到。
    $output = & ssh @sshArgs 2>&1
    $code = $LASTEXITCODE
}
catch {
    Write-Host "SSH 执行失败: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$problems = Format-RemoteOutput -Lines @($output)

Write-Host ''
if ($code -ne 0) {
    Write-Host "ssh 退出码 $code（远端命令可能部分失败，上面有细节）" -ForegroundColor Yellow
}

if ($Action -eq 'wake' -or $Action -eq 'deskflow') {
    $running = @($output) -match '^deskflow=running'
    $restarted = @($output) -match '^restarted=yes'
    if ($running -and $restarted) {
        Write-Host "完成：显示器已唤醒，deskflow 已重启并在运行。" -ForegroundColor Green
    }
    elseif ($running) {
        Write-Host "显示器已唤醒，deskflow 在运行（重启步骤未执行）。" -ForegroundColor Green
    }
    else {
        Write-Host "deskflow 没起来。跑 'mac-doctor' 把输出发我。" -ForegroundColor Yellow
        if (@($output) -match '^gui_domain=no') {
            Write-Host "  → 关键线索：gui 域不存在，说明那台 Mac 没有人在图形界面登录。" -ForegroundColor Yellow
            Write-Host "    先到 Mac 前面手动登录一次。" -ForegroundColor Yellow
        }
    }
}

if ($Action -eq 'doctor' -and $problems.Count -gt 0) {
    Write-Host ''
    Write-Host "发现 $($problems.Count) 条待处理：" -ForegroundColor Yellow
    $problems | Select-Object -Unique | ForEach-Object { Write-Host "  · $_" -ForegroundColor Yellow }
}

exit $code
