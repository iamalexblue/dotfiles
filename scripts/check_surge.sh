#!/bin/sh
echo "Last run: $(date)" > /tmp/check_surge.status
SURGE_IP="10.10.10.10"
SURGE_PORT="6152"

# 探测 Surge
if nc -z -w 3 $SURGE_IP $SURGE_PORT > /dev/null; then
    # Surge 在线
    if [ "$(uci get dhcp.lan.ignore)" != "1" ]; then
        logger "Surge ONLINE: Switching R2S DHCP to OFF."
        uci set dhcp.lan.ignore='1'
        uci commit dhcp
        /sbin/reload_config
    else
        echo "Surge is ONLINE and R2S DHCP is already OFF. Doing nothing."
    fi
else
    # Surge 离线
    if [ "$(uci get dhcp.lan.ignore)" == "1" ]; then
        logger "Surge OFFLINE: Switching R2S DHCP to ON (Backup Mode)."
        uci set dhcp.lan.ignore='0'
        uci commit dhcp
        /sbin/reload_config
    else
        echo "Surge is OFFLINE and R2S DHCP is already ON. Standing by."
    fi
fi
