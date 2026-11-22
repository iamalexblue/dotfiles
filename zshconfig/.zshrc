# ===============================================================
# 1. Oh My Zsh 核心
# ===============================================================

export ZSH="$HOME/.oh-my-zsh"
# ZSH_THEME="eastwood"

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
# 脚本本体：~/.config/zsh/proxy.zsh
# 命令：pon [mihomo|surge] / poff / proxy on|off|status / pst / pupdate
# ===============================================================
[[ -r ~/.config/zsh/proxy.zsh ]] && source ~/.config/zsh/proxy.zsh

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
# 用户级二进制目录（uv、Antigravity CLI、magpie 等都装在这里，只需加一次）
export PATH="$HOME/.local/bin:$PATH"

# ---- Google Cloud SDK ----
if [ -f '/home/realexblue/google-cloud-sdk/path.zsh.inc' ]; then . '/home/realexblue/google-cloud-sdk/path.zsh.inc'; fi
if [ -f '/home/realexblue/google-cloud-sdk/completion.zsh.inc' ]; then . '/home/realexblue/google-cloud-sdk/completion.zsh.inc'; fi

# ---- opencode ----
export PATH="/home/realexblue/.opencode/bin:$PATH"

# ---- System Path ----
export PATH="/usr/local/bin:$PATH"
export PATH="$PATH:/usr/sbin"

# ---- QODER_DISPATCHER_PATH v1 ----
path=("$HOME/.qoder/entry" ${path:#"$HOME/.qoder/entry"})
export PATH

# ---- Bitwarden (Flatpak) 的 SSH agent socket ----
# 实际路径在 .var/app 沙箱数据目录下，不是 $HOME/.bitwarden-ssh-agent.sock（那个路径从来不存在）。
export SSH_AUTH_SOCK="$HOME/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock"

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
if command -v thefuck >/dev/null 2>&1; then
    eval "$(thefuck --alias)"
    eval "$(thefuck --alias fk)"
fi

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

# ===============================================================
# 8. DSH NEXT 桌面端自动更新
# 脚本本体：~/dev/dsh-next/install/update.sh   包装：~/.config/zsh/dsh-next-update.zsh
# 命令：dsh update / dsh update --check，其他 dsh 子命令照旧透传 npm CLI
# ===============================================================
[[ -r ~/.config/zsh/dsh-next-update.zsh ]] && source ~/.config/zsh/dsh-next-update.zsh

# >>> magpie agy >>>
unalias agy 2>/dev/null || true
agy() {
  if [ -x '/home/realexblue/.local/bin/magpie' ]; then '/home/realexblue/.local/bin/magpie' agy run "$@"; else command agy "$@"; fi
}
# <<< magpie agy <<<
