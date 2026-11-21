# ===============================================================
# 1. Oh My Zsh 核心
# ===============================================================

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="eastwood"

# ---- 功能开关 (取消注释即可生效) ----
# CASE_SENSITIVE="true"
# HYPHEN_INSENSITIVE="true"
# zstyle ':omz:update' mode disabled
# zstyle ':omz:update' frequency 13
# DISABLE_LS_COLORS="true"
# ENABLE_CORRECTION="true"
# COMPLETION_WAITING_DOTS="true"

# ---- 插件 ----
plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# ===============================================================
# 2. 终端与 Shell 体验
# ===============================================================

export TERMINAL=kitty

# 语言环境
# export LANG=en_US.UTF-8

# 默认编辑器
export EDITOR='nvim'
export VISUAL='nvim'

eval "$(starship init zsh)"

# ===============================================================
# 3. 代理管理 — 默认本地 Mihomo，可选 Mac Mini Surge
# ===============================================================

# 代理端点配置
export MIHOMO_PROXY="http://127.0.0.1:7890"
export SURGE_HTTP="http://10.10.10.10:6152"
export SURGE_SOCKS="socks5://10.10.10.10:6153"

# 不走代理的地址 (镜像站 / 内网)
export no_proxy="hf-mirror.com,modelscope.cn,localhost,127.0.0.1,.local"
export NO_PROXY="$no_proxy"

# 记录当前使用的代理 (内部变量, 供 poff 提示用)
_CURRENT_PROXY=""

# _check_port — 内部函数: 检测 TCP 端口是否可达
function _check_port() {
    local host="$1" port="$2" label="$3"
    if nc -z -w 2 "$host" "$port" 2>/dev/null; then
        printf "\033[32m[✔] %s → %s:%s 可达\033[0m\n" "$label" "$host" "$port"
        return 0
    else
        printf "\033[33m[!] %s → %s:%s 不可达 (服务未启动?)\033[0m\n" "$label" "$host" "$port"
        return 1
    fi
}

# _check_direct — 内部函数: 检测直连是否正常
function _check_direct() {
    if curl -s --max-time 3 https://www.google.com > /dev/null 2>&1; then
        printf "\033[32m[✔] 直连正常 (Google 可达)\033[0m\n"
    else
        printf "\033[33m[!] 直连异常 (Google 不可达, 请检查网络)\033[0m\n"
    fi
}

# pon — 开启代理 (默认使用本地 Mihomo)
# Usage: pon           → 本地 Mihomo (localhost:7890)
#        pon surge     → Mac Mini Surge (10.10.10.10:6152)
#        pon mihomo    → 显式指定本地 Mihomo
function pon() {
    local target="${1:-mihomo}"
    case "$target" in
        mihomo|mh)
            export http_proxy="$MIHOMO_PROXY"
            export https_proxy="$MIHOMO_PROXY"
            export all_proxy="$MIHOMO_PROXY"
            export _CURRENT_PROXY="Mihomo (本地)"
            printf "\033[32m[✔] Mihomo Proxy Enabled (%s)\033[0m\n" "$MIHOMO_PROXY"
            _check_port "127.0.0.1" "7890" "Mihomo"
            ;;
        surge|sf)
            export http_proxy="$SURGE_HTTP"
            export https_proxy="$SURGE_HTTP"
            export all_proxy="$SURGE_SOCKS"
            export _CURRENT_PROXY="Surge (Mac Mini)"
            printf "\033[32m[✔] Surge  Proxy Enabled (HTTP %s | SOCKS %s)\033[0m\n" \
                "$SURGE_HTTP" "$SURGE_SOCKS"
            _check_port "10.10.10.10" "6152" "Surge"
            ;;
        *)
            printf "\033[33m[!] 未知代理: %s\033[0m\n" "$target"
            printf "Usage: pon [mihomo|surge]\033[0m\n"
            return 1
            ;;
    esac
}

# poff — 关闭代理 (无论当前用的是哪个)
function poff() {
    if [ -z "$http_proxy" ] && [ -z "$all_proxy" ]; then
        printf "\033[33m[!] 当前没有开启代理\033[0m\n"
        return 0
    fi
    unset http_proxy https_proxy ftp_proxy all_proxy
    printf "\033[31m[✘] %s Proxy Disabled\033[0m\n" "${_CURRENT_PROXY:-Proxy}"
    unset _CURRENT_PROXY
    _check_direct
}

# proxy — 统一代理入口
# Usage: proxy on [mihomo|surge]  |  proxy off  |  proxy status
function proxy() {
    case "${1:-status}" in
        on)       pon "$2" ;;
        off)      poff ;;
        status|st) env | grep -i proxy || printf "\033[33m[!] 未设置任何代理变量\033[0m\n" ;;
        *)        printf "\033[33mUsage: proxy {on <name>|off|status}\033[0m\n" ;;
    esac
}

alias pst='proxy status'

# 更新 Mihomo 代理（pupdate = Proxy Update）
function pupdate() {
    curl -X PUT http://127.0.0.1:9090/providers/proxies/ytoo
}

# ===============================================================
# 4. 开发环境
# ===============================================================

# ---- Node.js (fnm) ----
FNM_PATH="/home/realexblue/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "$(fnm env --shell zsh)"
fi

# ---- bun ----
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "/home/realexblue/.bun/_bun" ] && source "/home/realexblue/.bun/_bun"

# ---- Python (uv) ----
[[ -f "$HOME/.local/bin/env" ]] && source "$HOME/.local/bin/env"
export PATH="$HOME/.local/bin:$PATH"

# ---- Google Cloud SDK ----
if [ -f '/home/realexblue/google-cloud-sdk/path.zsh.inc' ]; then . '/home/realexblue/google-cloud-sdk/path.zsh.inc'; fi
if [ -f '/home/realexblue/google-cloud-sdk/completion.zsh.inc' ]; then . '/home/realexblue/google-cloud-sdk/completion.zsh.inc'; fi

# ---- opencode ----
export PATH=/home/realexblue/.opencode/bin:$PATH

# ---- System Path ----
export PATH="/usr/local/bin:$PATH"
export PATH=$PATH:/usr/sbin

# ---- QODER_DISPATCHER_PATH v1 ----
path=("$HOME/.qoder/entry" ${path:#"$HOME/.qoder/entry"})
export PATH

# ---- Added by Antigravity CLI installer ----
export PATH="/home/realexblue/.local/bin:$PATH"

# ---- Bitwarden (Flatpak) 的 SSH agent socket ----
# 实际路径在 .var/app 沙箱数据目录下，不是 $HOME/.bitwarden-ssh-agent.sock（那个路径从来不存在）。
export SSH_AUTH_SOCK="$HOME/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock"

# ---- magpie agy ----
unalias agy 2>/dev/null || true
agy() {
  if [ -x '/home/realexblue/.local/bin/magpie' ]; then '/home/realexblue/.local/bin/magpie' agy run "$@"; else command agy "$@"; fi
}

# ===============================================================
# 5. 便捷工具
# ===============================================================

alias zshconfig="nvim ~/.zshrc"
alias reload="source ~/.zshrc"
# sudo nvim 不行因为 root home 下没你的配置 —— sudoedit 复制到 /tmp 用你的 nvim 编辑
alias sev='sudoedit'
# kitty SSH kitten — 仅 kitty 内启用
if [[ "$TERM" == "xterm-kitty" ]] && [[ -n "$KITTY_WINDOW_ID" ]]; then
    alias ssh="kitten ssh"
fi

# ---- TheFuck ----
eval $(thefuck --alias)
eval $(thefuck --alias fk)

# ---- yazi 文件管理器 (退出时自动 cd) ----
function y() {
        local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
        command yazi "$@" --cwd-file="$tmp"
        IFS= read -r -d '' cwd < "$tmp"
        [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
        rm -f -- "$tmp"
}

# ---- gearlever (Flatpak) ----
alias gearlever='flatpak run it.mijorus.gearlever'

# ---- mihomo 日志 (lnav 高亮) ----
# sudo -v 预热凭证；journalctl -o json 输出 JSON 给 lnav 做语法高亮（lnav 内置 journald_json_log 格式）
# kitty 的 xterm-kitty terminfo 与 ncurses 不完全兼容，切换为 xterm-256color
unalias mlog 2>/dev/null
mlog() {
    sudo -v || return 1
    if [[ "$TERM" == "xterm-kitty" ]]; then
        TERM=xterm-256color sudo -E journalctl -u mihomo -o json -n 100 -f | TERM=xterm-256color lnav
    else
        sudo journalctl -u mihomo -o json -n 100 -f | lnav
    fi
}
unalias mlog-last 2>/dev/null
mlog-last() {
    if [[ "$TERM" == "xterm-kitty" ]]; then
        TERM=xterm-256color sudo -E journalctl -u mihomo -o json -n 50 --no-pager | TERM=xterm-256color lnav
    else
        sudo journalctl -u mihomo -o json -n 50 --no-pager | lnav
    fi
}

# ===============================================================
# 6. Mac Mini 远程控制（与 Windows 端 MacMiniControl.ps1 同构）
# 脚本本体：~/.config/zsh/mac-mini-control.zsh
# 命令：mac-wake / mac-sleep / mac-status / mac-fix / mac-doctor / mac-edit / mac-help
# ===============================================================
[[ -r ~/.config/zsh/mac-mini-control.zsh ]] && source ~/.config/zsh/mac-mini-control.zsh

# ===============================================================
# 7. openSUSE 系统管理
# ===============================================================

# 一键刷新所有关闭了自动刷新的 OBS 三方仓库
refobs() {
    local repos
    repos=$(LC_ALL=C zypper lr -d 2>/dev/null | awk -F'|' 'NR>2 && $6 ~ /No/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
    if [[ -z "$repos" ]]; then
        echo "没有需要手动刷新的仓库。"
        return
    fi
    echo "正在刷新以下仓库："
    echo "$repos"
    echo "$repos" | xargs pkexec zypper refresh --repo
}


