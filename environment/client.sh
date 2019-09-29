#!/usr/bin/env ash

set -e

SCRIPTS_DIR="$(dirname $(dirname $(readlink -f $0)))/scripts"

## -- Base configuration
export HOSTNAME="${HOSTNAME:-openwrt-master}"
# LUCI_DISABLE=1
$SCRIPTS_DIR/base/begin.sh
$SCRIPTS_DIR/base/luci.sh
$SCRIPTS_DIR/base/authentication.sh
$SCRIPTS_DIR/base/ntp.sh

## -- Network configuration example
exit 0 # The rest of this is just examples!

# Supposing the client is not a DNS/DHCP relay, these are unnecessary.
opkg remove odhcpd-ipv6only dnsmasq
uci -q delete dhcp.@dnsmasq[0]
uci -q delete dhcp.lan
uci commit dhcp

## Use the device's WAN port to connect to the master switch.
# In this case, there is no WAN, so to speak, because we are using
# VLANs for routing. For a WRT3200ACM, the ports look something like
# 0 1 2 3: 4-port switch on the router (the numbers are backwards - 0..3=4..1)
# 4: eth0, the router CPU
# 5: the WAN port
# 6: the WAN interface
uci set network.@switch_vlan[0].ports='0 1 2 3 4t 5t 6t'

# Most likely you will be using this device as a switching AP instead of
# a router, so we can dump all that WAN stuff completely.
# WARNING: Don't do this unless you know what you're doing, as if connectivity does
# not work as expected, you will be doing a factory reset!
# This assumes all the firewall rules are about WAN traffic, the WAN
# uses VLAN 2 (with index 1), the first forwarding is lan->wan, and
# the second firewall zone (with index 1) is for the WAN.
for i in $(seq 0 $(($(uci show firewall | grep -c "=rule")-1))); do
    uci delete firewall.@rule[$i]
done
uci batch <<EOF
delete network.@switch_vlan[1]
delete network.wan
delete network.wan6
delete dhcp.wan
delete firewall.@forwarding[0]
delete firewall.@zone[1]
EOF

uci commit network
uci commit dhcp
uci commit firewall

## Create a new WiFi
uci -q delete wireless.default_radio0 # Delete the existing default wifi
new_wifi 'radio0' 'lan' 'my-wifi-ssid' 'secr3t' # Make a new WiFi on the LAN

## Create a guest WiFi
add_client_network 'guest' '192.168.3.2'
uci set network.@switch_vlan[-1].ports='4t 5t 6t'
uci commit network

new_wifi 'radio1' 'guest' 'guest-ssid' 'supersecr3t'
uci set wireless.@wifi-iface[-1].isolate=1
uci commit wireless
