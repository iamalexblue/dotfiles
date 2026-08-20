#!/bin/bash
# iStoreOS 智能重启检测脚本（由 systemd timer 每 3 分钟触发）
# 逻辑：外网多目标检测 → 连续失败 → 全面确认 → SSH 重启路由器
# 平时网络正常时零操作

LOG=/var/log/router-smart-reboot.log
FAIL=/tmp/router-net-fail
COOL=/tmp/router-rebooted-at
THRESHOLD=2          # 连续失败次数达到则进入确认
COOLDOWN=600         # 重启后冷却 10 分钟
GW=10.10.10.1
HOSTS="223.5.5.5 119.29.29.29 114.114.114.114"

# 冷却期内不动作（重启后等网络恢复）
if [ -f "$COOL" ]; then
    if [ $(( $(date +%s) - $(cat "$COOL") )) -lt $COOLDOWN ]; then
        rm -f "$FAIL"
        exit 0
    fi
fi

# 快速检测：任一国内 DNS 可达即视为网络正常
ok=0
for h in $HOSTS; do
    if ping -c 1 -W 2 "$h" >/dev/null 2>&1; then ok=1; break; fi
done
if [ "$ok" -eq 1 ]; then
    rm -f "$FAIL"
    exit 0
fi

# 网络不通，累计失败次数
n=$(cat "$FAIL" 2>/dev/null || echo 0)
n=$((n + 1))
echo "$n" > "$FAIL"
echo "$(date '+%F %T') 外网不通 (连续 $n 次)" >> "$LOG"
[ "$n" -lt "$THRESHOLD" ] && exit 0

# 全面确认：再次多目标检测
confirm=0
for h in $HOSTS; do
    if ping -c 2 -W 2 "$h" >/dev/null 2>&1; then confirm=1; break; fi
done
if [ "$confirm" -eq 1 ]; then
    echo "$(date '+%F %T') 确认阶段网络已恢复，取消重启" >> "$LOG"
    rm -f "$FAIL"
    exit 0
fi

# 确认网络故障，检查网关是否可达（路由器是否还活着）
if ping -c 1 -W 2 "$GW" >/dev/null 2>&1; then
    echo "$(date '+%F %T') 确认网络故障，SSH 重启 iStoreOS..." >> "$LOG"
    if ssh -o BatchMode=yes -o ConnectTimeout=8 root@"$GW" reboot; then
        date +%s > "$COOL"
        echo "$(date '+%F %T') 重启命令已发送，进入 10 分钟冷却期" >> "$LOG"
    else
        echo "$(date '+%F %T') SSH 重启命令发送失败" >> "$LOG"
    fi
else
    echo "$(date '+%F %T') 网关不可达（路由器可能完全卡死），无法 SSH 重启，需人工断电处理" >> "$LOG"
fi
rm -f "$FAIL"
exit 0

