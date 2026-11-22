# ===============================================================
# proxy.zsh — 代理管理（由 ~/.zshrc 第 3 节 source 引入）
# 默认本地 Mihomo，可选 Mac Mini Surge
# 命令：pon [mihomo|surge] / poff / proxy on|off|status / pst / pupdate
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
