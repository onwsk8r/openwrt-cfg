#!/usr/bin/env sh
# Make LuCi listen on SSL, optionally only on LAN or disabled
# Variables:
# LUCI_LAN if -n, LuCi will be configured to listen on only the current LAN IP
# LUCI_DISABLE if -n, LuCi service will be disabled but not stopped

# luci-proto-ipv6 may already be installed
opkg install luci-ssl luci-proto-ipv6

## Only listen on LAN interface
if [ -n "${LUCI_LAN}" ]; then
    LAN_IP=$(uci get network.lan.ipaddr)
    echo "Configuring LuCi to listen on $LAN_IP only"
    uci set uhttpd.main.listen_http="${LAN_IP}:80"
    uci set uhttpd.main.listen_https="${LAN_IP}:443"
    uci commit uhttpd
fi

## Disable LuCi
if [ -n "${LUCI_DISABLE}" ]; then
    echo "Disabling LuCi service"
    /etc/init.d/uhttpd disable
fi
/etc/init.d/uhttpd restart
