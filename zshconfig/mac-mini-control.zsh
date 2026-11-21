# ==============================================================================
# Mac mini 控制（deskflow 主机）—— Linux/zsh 端
# Windows 端对应物：PowerShell\Scripts\MacMiniControl.ps1
#
# 设计：发到 mini 上的远端脚本与 Windows 版逐字一致（它本来就是 bash），
#       本地只负责【一次 ssh 连接】+ 渲染输出。保证两端执行效果相同。
#
# 命令（mac 开头 + 动词，一条命令一件事，与 Windows 完全一致）：
#   mac-wake      唤醒显示器 + 重启 deskflow（默认，最常用）
#   mac-sleep     让显示器睡眠（系统保持唤醒）
#   mac-status    只查看当前状态，不改动
#   mac-fix       只重启 deskflow，不碰显示器
#   mac-doctor    完整体检，出问题先跑这个，把输出发我
#   mac-edit      用编辑器打开本脚本
#   mac-help      打印用法
#
# 通用参数（Linux 端长参数风格，语义与 Windows 的 -WakeSeconds 等一致）：
#   --wake-seconds N   caffeinate 唤醒持续秒数（1-60，默认 2）
#   --timeout N        SSH 连接超时（5-120，默认 15）
#   --ssh-host H       ssh config 里的 Host 别名（默认 mac-mini）
#   --force            跳过 LaunchAgent/应用作业路线，直接 kill+submit 强重启
#   --dry-run          只打印将要发到远端的脚本，不真连
#
# Linux 端特有说明：
#   1) ssh 固定带 -F ~/.ssh/config：openSUSE TW 的 idmapped 视图下
#      /usr/etc/ssh 属主映射为 nobody，OpenSSH 10.x 启动期严格检查直接拒绝
#      读全局配置（"Bad owner or permissions"）。-F 完全绕过，不受其影响。
#   2) MACMINI_SSH_OPTS 环境变量：调试用，按空格拆词追加到 ssh 参数
#      （例如临时指定 known_hosts）。日常不要用。
#   3) 与 Windows 的差异：Windows 的 -Force 是死代码（它的文本替换目标串在远端
#      脚本里根本不存在）。这里把 FORCE 做成真实开关，效果如上。
#   4) 旧的 wmac / wmac-v / wmac-full / smac 已删除（Windows 侧同样删除）；
#      WoL 不在本套命令里（Windows 版就没有）——mini 日常只关显示器不睡眠整机。
# ==============================================================================

# 脚本本体路径（mac-edit 用）
typeset -g MACMINI_SCRIPT_PATH=${${(%):-%N}:a}

# ---- ANSI 颜色（不依赖 tput/终端主题）----
typeset -g _MC_RESET=$'\e[0m'  _MC_BOLD=$'\e[1m'
typeset -g _MC_RED=$'\e[31m'   _MC_GREEN=$'\e[32m' _MC_YELLOW=$'\e[33m'
typeset -g _MC_CYAN=$'\e[36m'  _MC_GRAY=$'\e[37m'
typeset -g _MC_DGRAY=$'\e[90m' _MC_DYELLOW=$'\e[93m'

# ==============================================================================
# 远端脚本块 —— 与 MacMiniControl.ps1 里的 here-string 逐字对应
# （全部用带引号 heredoc，防止 zsh 抢先展开 $ 变量）
# ==============================================================================

# 公共前置：探测 uid / 控制台属主 / deskflow plist / 应用作业 / gui 域
_mac_block_prelude() {
  cat <<'MAC_EOF'
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
MAC_EOF
}

_mac_block_wake() {
  cat <<'MAC_EOF' | sed "s/__WAKE__/$1/g"
echo "### WAKE"
if command -v caffeinate >/dev/null 2>&1; then
  caffeinate -u -t __WAKE__ 2>&1 | sed 's/^/  /'
  echo "ok=caffeinate 完成(__WAKE__ s)"
else
  echo "warn=没有 caffeinate"
fi
MAC_EOF
}

_mac_block_sleep() {
  cat <<'MAC_EOF'
echo "### SLEEP"
if command -v pmset >/dev/null 2>&1; then
  pmset displaysleepnow 2>&1 | sed 's/^/  /'
  echo "ok=已请求显示器睡眠"
else
  echo "warn=没有 pmset"
fi
MAC_EOF
}

_mac_block_deskflow() {
  cat <<'MAC_EOF' | sed "s/__FORCE__/$1/g"
echo "### DESKFLOW"
FORCE=__FORCE__
RESTARTED=no

# 找 app 路径
APP=""
for cand in "/Applications/Deskflow.app" "$HOME/Applications/Deskflow.app" "/Applications/Deskflow Client.app"; do
  if [ -d "$cand" ]; then APP="$cand"; break; fi
done

# 路线 A：老的 LaunchAgent（Deskflow <= 1.26 或手动装的）
if [ -n "$LABEL" ] && [ "$LOADED" = "yes" ] && [ "$FORCE" != "yes" ]; then
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
if [ "$RESTARTED" = "no" ] && [ -n "$APP_LABEL" ] && [ "$FORCE" != "yes" ]; then
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
MAC_EOF
}

# 状态 / 结果汇总
_mac_block_report() {
  cat <<'MAC_EOF'
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
MAC_EOF
}

_mac_block_doctor() {
  cat <<'MAC_EOF'
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
MAC_EOF
}

# ==============================================================================
# 输出渲染：把远端 Key=Value 行变成好读的形式；warn/hint 收集进 _MAC_PROBLEMS
# ==============================================================================
typeset -ga _MAC_PROBLEMS

_mac_format_output() {
  emulate -L zsh
  local l k v name n color
  _MAC_PROBLEMS=()
  while IFS= read -r l; do
    l=${l%$'\r'}
    case $l in
      '### '*)
        name=${l#'### '}
        n=$(( 40 - ${#name} )); (( n < 1 )) && n=1
        print ''
        print -r -- "${_MC_CYAN}-- ${name} ${_MC_DGRAY}${(l:n::-:)}${_MC_RESET}"
        ;;
      'ok='*)
        print -r -- "${_MC_GREEN}  OK   ${_MC_RESET}${l#ok=}"
        ;;
      'warn='*)
        _MAC_PROBLEMS+=("${l#warn=}")
        print -r -- "${_MC_YELLOW}  WARN ${_MC_RESET}${l#warn=}"
        ;;
      'info='*)
        print -r -- "${_MC_CYAN}  INFO ${_MC_RESET}${l#info=}"
        ;;
      'hint='*)
        _MAC_PROBLEMS+=("${l#hint=}")
        print -r -- "${_MC_DYELLOW}  HINT ${_MC_RESET}${l#hint=}"
        ;;
      *=*)
        k=${l%%=*}; v=${l#*=}
        color=${_MC_GRAY}
        case $k in
          label|plist|plist_disabled|loaded|app_label|app_pid|gui_domain|uid|user|console_user|sw_vers|deskflow|pids|display|restarted)
            [[ $k == loaded     && $v == yes     ]] && color=${_MC_GREEN}
            [[ $k == loaded     && $v == no      ]] && color=${_MC_DGRAY}
            [[ $k == restarted  && $v == yes     ]] && color=${_MC_GREEN}
            [[ $k == restarted  && $v == no      ]] && color=${_MC_YELLOW}
            [[ $k == deskflow   && $v == running ]] && color=${_MC_GREEN}
            [[ $k == deskflow   && $v == stopped ]] && color=${_MC_RED}
            [[ $k == gui_domain && $v == no      ]] && color=${_MC_RED}
            [[ $k == display    && $v == unknown ]] && color=${_MC_DGRAY}
            [[ $k == plist_disabled              ]] && color=${_MC_DYELLOW}
            print -r -- "${color}  $(printf '%-15s' "$k") ${v}${_MC_RESET}"
            ;;
          *)
            print -r -- "${_MC_DGRAY}  ${l}${_MC_RESET}"
            ;;
        esac
        ;;
      *)
        print -r -- "${_MC_DGRAY}  ${l}${_MC_RESET}"
        ;;
    esac
  done <<< "$1"
}

# ==============================================================================
# 主实现
# ==============================================================================
_mac_control() {
  emulate -L zsh
  local action=$1; shift

  if [[ ${1:-} == (-h|--help) ]]; then _mac_help; return 0; fi

  local wake_seconds=2 timeout=15 ssh_host='mac-mini' force='no' dry_run=0
  while (( $# > 0 )); do
    case $1 in
      --wake-seconds)
        [[ $# -ge 2 && $2 == <-> ]] || { print -u2 "mac-$action: --wake-seconds 需要一个数字（1-60）"; return 2; }
        (( $2 >= 1 && $2 <= 60 )) || { print -u2 "mac-$action: --wake-seconds 需在 1-60，当前 $2"; return 2; }
        wake_seconds=$2; shift 2 ;;
      --timeout)
        [[ $# -ge 2 && $2 == <-> ]] || { print -u2 "mac-$action: --timeout 需要一个数字（5-120）"; return 2; }
        (( $2 >= 5 && $2 <= 120 )) || { print -u2 "mac-$action: --timeout 需在 5-120，当前 $2"; return 2; }
        timeout=$2; shift 2 ;;
      --ssh-host)
        [[ $# -ge 2 && -n $2 ]] || { print -u2 "mac-$action: 缺少 --ssh-host 的值"; return 2; }
        ssh_host=$2; shift 2 ;;
      --force)   force='yes'; shift ;;
      --dry-run) dry_run=1; shift ;;
      -h|--help) _mac_help; return 0 ;;
      *) print -u2 "mac-$action: 未知参数 '$1'（用法见 mac-help）"; return 2 ;;
    esac
  done

  # ---- 组装远端脚本（与 Windows 版同样的分块拼接）----
  local -a parts=()
  parts+=( "$(_mac_block_prelude)" )
  case $action in
    wake)     parts+=( "$(_mac_block_wake "$wake_seconds")" "$(_mac_block_deskflow "$force")" "$(_mac_block_report)" ) ;;
    sleep)    parts+=( "$(_mac_block_sleep)" ) ;;
    deskflow) parts+=( "$(_mac_block_deskflow "$force")" "$(_mac_block_report)" ) ;;
    status)   parts+=( "$(_mac_block_report)" ) ;;
    doctor)   parts+=( "$(_mac_block_doctor)" "$(_mac_block_report)" ) ;;
  esac
  local remote=${(F)parts}

  if (( dry_run )); then
    print -r -- "${_MC_DGRAY}===== 将要发送到 $ssh_host 的脚本 =====${_MC_RESET}"
    print -r -- "$remote"
    print -r -- "${_MC_DGRAY}===== 结束 =====${_MC_RESET}"
    return 0
  fi

  # ---- 头 ----
  if [[ $action == doctor ]]; then
    print -r -- "${_MC_CYAN}== Mac mini 体检 ($ssh_host) ==${_MC_RESET}"
  else
    print -r -- "${_MC_CYAN}== Mac mini: $action ==${_MC_RESET}"
  fi

  # ---- 执行 ----
  # 关键：整段脚本 base64 后一次性发出 => 只有一次 ssh 连接，只认证一次。
  # 用 base64 而不是 stdin 重定向：stdin 留给 ssh 自己（密码提示/交互才正常）。
  local b64 cmd output code=0
  b64=$(print -r -- "$remote" | base64 -w0)
  cmd="echo $b64 | base64 -d | bash"

  local -a ssh_args=()
  [[ -n ${MACMINI_SSH_OPTS:-} ]] && ssh_args+=( ${=MACMINI_SSH_OPTS} )
  # openSUSE 全局 ssh_config 属主问题 => 固定 -F 用户配置（见文件头注释）
  [[ -f "$HOME/.ssh/config" ]] && ssh_args+=( -F "$HOME/.ssh/config" )
  ssh_args+=( -o "ConnectTimeout=$timeout" -o 'ServerAliveInterval=5' -- "$ssh_host" "$cmd" )

  if ! command -v ssh >/dev/null 2>&1; then
    print -u2 "${_MC_RED}找不到 ssh 命令${_MC_RESET}"
    return 1
  fi
  output=$(ssh "${ssh_args[@]}" 2>&1) || code=$?

  _mac_format_output "$output"

  print ''
  if (( code != 0 )); then
    print -r -- "${_MC_YELLOW}ssh 退出码 $code（远端命令可能部分失败，上面有细节）${_MC_RESET}"
  fi

  # ---- 结论（与 Windows 版同文案同逻辑）----
  if [[ $action == wake || $action == deskflow ]]; then
    local -a rlines=( "${(@f)output}" )
    local running=0 restarted=0
    (( ${#rlines[(r)deskflow=running]} )) && running=1
    (( ${#rlines[(r)restarted=yes]} ))   && restarted=1
    if (( running && restarted )); then
      print -r -- "${_MC_GREEN}完成：显示器已唤醒，deskflow 已重启并在运行。${_MC_RESET}"
    elif (( running )); then
      print -r -- "${_MC_GREEN}显示器已唤醒，deskflow 在运行（重启步骤未执行）。${_MC_RESET}"
    else
      print -r -- "${_MC_YELLOW}deskflow 没起来。跑 'mac-doctor' 把输出发我。${_MC_RESET}"
      if (( ${#rlines[(r)gui_domain=no]} )); then
        print -r -- "${_MC_YELLOW}  → 关键线索：gui 域不存在，说明那台 Mac 没有人在图形界面登录。${_MC_RESET}"
        print -r -- "${_MC_YELLOW}    先到 Mac 前面手动登录一次。${_MC_RESET}"
      fi
    fi
  fi

  if [[ $action == doctor ]] && (( ${#_MAC_PROBLEMS} > 0 )); then
    print ''
    print -r -- "${_MC_YELLOW}发现 ${#_MAC_PROBLEMS} 条待处理：${_MC_RESET}"
    local p
    for p in ${(u)_MAC_PROBLEMS}; do
      print -r -- "${_MC_YELLOW}  · $p${_MC_RESET}"
    done
  fi

  return $code
}

# ==============================================================================
# 命令入口（与 Windows 端同名）
# ==============================================================================
mac-wake()   { _mac_control wake      "$@"; }
mac-sleep()  { _mac_control sleep     "$@"; }
mac-status() { _mac_control status    "$@"; }
mac-fix()    { _mac_control deskflow  "$@"; }
mac-doctor() { _mac_control doctor    "$@"; }
mac-edit()   { ${EDITOR:-nvim} "$MACMINI_SCRIPT_PATH"; }

mac-help()   { _mac_help; }

_mac_help() {
  local R=${_MC_RESET} T=${_MC_CYAN} D=${_MC_DGRAY} G=${_MC_GREEN} Y=${_MC_DYELLOW} E=${_MC_GRAY}
  local rule="  ------------------------------------------------------------"

  print ''
  print -r -- "  ${T}Mac mini 控制（Linux 端）${R}"
  print -r -- "$rule"
  # 列宽按显示宽度手工对齐（CJK=2）：命令列 12，描述列 40
  print -r -- "   ${G}mac-wake${R}      唤醒 Mac：点亮显示器 + 重启 deskflow   ${Y}[ 最常用 ]${R}"
  print -r -- "   ${G}mac-sleep${R}     让 Mac 显示器睡眠（系统保持唤醒）${R}"
  print -r -- "   ${G}mac-status${R}    查看现状：deskflow / 登录状态${R}"
  print -r -- "   ${G}mac-fix${R}       只重启 deskflow，不碰显示器${R}"
  print -r -- "   ${G}mac-doctor${R}    完整体检，出问题先跑这个               ${Y}[ 排障 ]${R}"
  print -r -- "   ${G}mac-edit${R}      用 EDITOR(默认 nvim) 打开控制脚本${R}"
  print -r -- "   ${G}mac-help${R}      显示这份帮助${R}"

  print ''
  print -r -- "  ${T}通用参数（mac-wake / mac-sleep / mac-fix 都适用）${R}"
  print -r -- "$rule"
  print -r -- "   ${E}--wake-seconds <n>   caffeinate 唤醒持续秒数，默认 2${R}"
  print -r -- "   ${E}--timeout <n>        SSH 连接超时，默认 15${R}"
  print -r -- "   ${E}--ssh-host <别名>    ssh config 里的主机名，默认 mac-mini${R}"
  print -r -- "   ${E}--force              跳过 kickstart 路线，kill 后强制重启${R}"
  print -r -- "   ${E}--dry-run            只打印将发到远端的脚本，不真连${R}"

  print ''
  print -r -- "  ${T}例子${R}"
  print -r -- "$rule"
  print -r -- "   ${E}mac-wake                     # 日常，唤醒 + 重启 deskflow${R}"
  print -r -- "   ${E}mac-wake --wake-seconds 10   # 屏幕太困，多唤一会儿${R}"
  print -r -- "   ${E}mac-status                   # 先看看现在什么情况${R}"
  print -r -- "   ${E}mac-doctor                   # 出问题了，体检${R}"

  print ''
  print -r -- "  ${T}说明${R}"
  print -r -- "$rule"
  print -r -- "   ${E}脚本本体       ~/.config/zsh/mac-mini-control.zsh${R}"
  print -r -- "   ${E}对照 Windows   PowerShell\\Scripts\\MacMiniControl.ps1${R}"
  print -r -- "   ${E}本机 SSH 前提  ssh -F ~/.ssh/config（绕过 openSUSE 全局配置属主检查）${R}"
  print -r -- "   ${E}               mini 需信任本机公钥：先 ssh-copy-id 打通免密${R}"
  print -r -- "   ${E}启动方式       Deskflow 1.27+ 用 launchctl submit${R}"
  print -r -- "   ${E}                （open -a 在 SSH 会话里会秒退）${R}"
  print ''
}
