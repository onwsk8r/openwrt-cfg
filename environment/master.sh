#!/usr/bin/env ash

set -e

BASE_DIR="$(dirname $(dirname $(readlink -f $0)))"
SCRIPTS_DIR="${BASE_DIR}/scripts"

## -- Base configuration
export HOSTNAME="${HOSTNAME:-openwrt-master}"
export LUCI_LAN=1
# LUCI_DISABLE=1
$SCRIPTS_DIR/base/begin.sh
$SCRIPTS_DIR/base/luci.sh
$SCRIPTS_DIR/base/authentication.sh
$SCRIPTS_DIR/base/ntp.sh

## -- DNS configuration
$SCRIPTS_DIR/dns/unbound.sh
$SCRIPTS_DIR/dns/adblock.sh

## -- Network configuration example
$SCRIPTS_DIR/network/sqm.sh

exit 0 # The rest of this is just examples!

source "${BASE_DIR}/functions/functions.sh"

# Enable STP since this is a master
# IGMP snooping is handy because the radio will crank down to the lowest speed
# for multicasts, and having many broadcasts can eat up all the airtime.
uci batch <<EOF
set network.lan.igmp_snooping=1
set network.lan.stp=1
EOF
uci commit network.lan

uci -q delete wireless.default_radio0 # Delete the existing default wifis
new_wifi 'radio0' 'lan' 'my-wifi' "${KEY}" # Make a WiFi on the LAN

## -- Make a whole new network
add_master_network 'guest' '10.10.220.1'
new_wifi 'radio1' 'guest' 'my-guests' 'secr3t'
uci set wireless.@wifi-iface[-1].isolate=1
uci commit wireless

## -- Put the Chromecast on a different network
add_master_network 'insecure' '10.0.220.1'
new_wifi 'radio0' 'insecure' 'unsafe-things' 'secret3r'
firewall_add_forward 'lan' 'insecure' # Allow access from the LAN

# Use avahi-daemon to pass multicasts between the interfaces
# Google devices, like Apple devices, use Zeroconf (read: mDNS)
AVAHI_IFS="br-lan,br-insecure"
$SCRIPTS_DIR/network/mdns.sh
