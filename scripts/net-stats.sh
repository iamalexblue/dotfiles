#!/bin/bash
# net-stats: 网络守护脚本状态总览（智能重启 + DHCP 主备切换）
# 用法: net-stats

echo "=============================================="
echo " 网络守护状态  $(date '+%F %T')"
echo "=============================================="

# ---------- 1. 路由器智能重启 ----------
echo ""
echo "[1] 路由器智能重启 (router-smart-reboot)"
echo "    Timer: $(systemctl is-active router-reboot-check.timer 2>/dev/null || echo unknown)"
next=$(systemctl show router-reboot-check.timer -p NextElapseUSecRealtime --value 2>/dev/null)
echo "    下次检测: ${next:-N/A}"
n=$(cat /tmp/router-net-fail 2>/dev/null || echo 0)
echo "    当前失败计数: $n / 2 (达 2 次触发确认)"
if [ -f /tmp/router-rebooted-at ]; then
    age=$(( ($(date +%s) - $(cat /tmp/router-rebooted-at)) / 60 ))
    if [ "$age" -lt 10 ]; then
        echo "    上次重启: ${age} 分钟前 [冷却中]"
    else
        echo "    上次重启: ${age} 分钟前"
    fi
else
    echo "    上次重启: 无记录"
fi
echo "    日志 (最近 5 条):"
tail -5 /var/log/router-smart-reboot.log 2>/dev/null | sed 's/^/      /' || echo "      (暂无日志)"

# ---------- 2. DHCP 主备切换 ----------
echo ""
echo "[2] DHCP 主备切换 (check_surge, 路由器上)"
surge_status=$(ssh -o BatchMode=yes -o ConnectTimeout=5 root@10.10.10.1 \
    "cat /tmp/check_surge.status 2>/dev/null | tail -1; echo -n '    DHCP ignore: '; uci get dhcp.lan.ignore" 2>/dev/null)
if [ -n "$surge_status" ]; then
    echo "$surge_status" | sed 's/^/    /'
else
    echo "    (无法连接路由器)"
fi
echo "    Surge 探测: $(timeout 3 bash -c 'echo > /dev/tcp/10.10.10.10/6152' 2>/dev/null && echo '在线 :6152' || echo '离线')"
echo ""
echo "----------------------------------------------"
echo " 提示: 平时网络正常时 [1] 应无日志; [2] ignore=1 表示 Surge 在管 DHCP"
echo "=============================================="

