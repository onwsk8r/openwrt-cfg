#!/bin/bash
# Update OpenWRT with my settings

## ===== Contents
# - Set root password and add SSH keys
# - Set timezone
# - Set up dnscrypt
# - Enable and configure mDNS
# - Configure network settings (ie subnets)
# - Configure wireless network settings

# Spanning tree protocol for WDS
# Forced DNS resolution
# - Enable QoS
# Make sure IPv6 works
# Set up ddns
# Static hosts in dnsmasq
# Look for anything about traffic monitoring, maybe ossec, kismet
# Make sure telnet is off!
# OpenVPN server and client
# Privoxy FTW!

set -eux




## ===== DNSCrypt
# https://openwrt.org/docs/guide-user/services/dns/dnscrypt
echo "Installing DNSCrypt..."
opkg install dnscrypt-proxy luci-app-dnscrypt-proxy

DNSCRYPT_RSLVR_URL="https://raw.githubusercontent.com/dyne/dnscrypt-proxy/master/dnscrypt-resolvers.csv"
DNSCRYPT_RSLVR_FILE="/usr/share/dnscrypt-proxy/resolvers.csv"

curl -O "$DNSCRYPT_RSLVR_FILE" "$DNSCRYPT_RSLVER_URL"

# Primary
echo "Creating primary DNSCrypt resolver..."
TARGET="dnscrypt-proxy.ns1"

set $TARGET.resolver='cisco-ipv6'
set $TARGET.port='5353'
set $TARGET.resolvers_list='$DNSCRYPT_RSLVR_FILE'
set $TARGET.local_cache=1
set $TARGET.block_ipv6=0
set $TARGET.query_log_file=ltsv:/tmp/dns-queries.log
EOF

# Backup
echo "Creating seconday DNSCrypt resolver..."
TARGET="dnscrypt-proxy.ns2"
uci batch <<EOF
add $TARGET
set $TARGET.address='127.0.0.1'
set $TARGET.port='5454'
set $TARGET.resolver='cisco-ipv6'
set $TARGET.resolvers_list='$DNSCRYPT_RSLVR_FILE'
set $TARGET.local_cache=1
set $TARGET.block_ipv6=0
set $TARGET.query_log_file=ltsv:/tmp/dns-queries.log
EOF

# Never be too careful...
echo "Creating tertiary DNSCrypt resolver..."
TARGET="dnscrypt-proxy.ns3"
uci batch <<EOF
add $TARGET
set $TARGET.address='127.0.0.1'
set $TARGET.port='5555'
set $TARGET.resolver='cisco-ipv6'
set $TARGET.resolvers_list='$DNSCRYPT_RSLVR_FILE'
set $TARGET.local_cache=1
set $TARGET.block_ipv6=0
set $TARGET.query_log_file=ltsv:/tmp/dns-queries.log
EOF

# Update dnsmasq
echo "Telling DNSMasq to use DNSCrypt..."
uci batch <<EOF
delete $TARGET.resolvfile
set $TARGET.noresolv=1
delete $TARGET.server
add_list $TARGET.server='127.0.0.1#5353'
add_list $TARGET.server='127.0.0.1#5454'
add_list $TARGET.server='127.0.0.1#5555'
add_list $TARGET.server='/pool.ntp.org/208.67.222.222'
EOF
uci commit


## ===== Enable Local DNS resoution with mDNS
# mDNS allows devices to look each other up by name
# This enables mDNS lookups on the LAN (br-lan) interface
opkg install avahi-daemon
echo 'Enabling mDNS on LAN interface'
sed -i.bak '/use-iff/ a \
allow-interfaces=br-lan \
enable-dbus=no ' /etc/avahi/avahi-daemon.conf
sed -i -e '/enable-reflector/s/no/yes/' /etc/avahi/avahi-daemon.conf
/etc/init.d/avahi-daemon enable
# /etc/init.d/avahi-daemon start
uci set dhcp.@dnsmasq[0].local='/bhaze.int/'
uci set dhcp.@dnsmasq[0].domain='bhaze.int'
uci commit dhcp


## ===== Configure local network


# ==============================
# Set Smart Queue Management (SQM) values for your own network
#
# Use a speed test (http://dslreports.com/speedtest) to determine
# the speed of your own network, then set the speeds  accordingly.
# Speeds below are in kbits per second (3000 = 3 megabits/sec)
# For details about setting the SQM for your router, see:
# http://wiki.openwrt.org/doc/howto/sqm
# Set DOWNLOADSPEED, UPLOADSPEED, WANIF and then uncomment 18 lines
#
# opkg install luci-app-sqm
# opkg install netperf
# DOWNLOADSPEED=20000
# UPLOADSPEED=2000
# WANIF=eth0
# echo 'Setting SQM on '$WANIF ' to ' $DOWNLOADSPEED/$UPLOADSPEED 'kbps down/up'
# uci set sqm.@queue[0].interface=$WANIF
# uci set sqm.@queue[0].enabled=1
# uci set sqm.@queue[0].download=$DOWNLOADSPEED
# uci set sqm.@queue[0].upload=$UPLOADSPEED
# uci set sqm.@queue[0].script='simple.qos'
# Already the default
# uci set sqm.@queue[0].qdisc='fq_codel'
# uci set sqm.@queue[0].itarget='auto'
# uci set sqm.@queue[0].etarget='auto'
# uci set sqm.@queue[0].linklayer='atm'
# uci set sqm.@queue[0].overhead='44'
# uci commit sqm # /etc/init.d/sqm restart
# /etc/init.d/sqm enable

# === Update IP Subnet Ranges ==================
# Changing configuration for Subnets, DNS, SSIDs, etc.
# See this page for details:
#    http://www.bufferbloat.net/projects/cerowrt/wiki/Changing_your_cerowrt_ip_addresses
# If you do any of these, you should reboot the router afterwards
#
# Subnet:
# Supply values for NEWIP and REVIP (e.g. 192.168.1 and 1.168.192, respectively)
#   in the lines below, then uncomment five lines
#
# NEWIP=your.new.ip
# REVIP=ip.new.your
# echo 'Changing IP subnets to' $NEWIP 'and' $REVIP
# sed -i s#172.30.42#$NEWIP#g /etc/config/*

# === Update WiFi info for the access point ================
# a) Assign the radio channels
# b) Assign the SSID's
# c) Assign the encryption/passwords
# To see all the wireless info:
#	uci show wireless
#
# Default interface indices and SSIDs are:
#	0 - CEROwrt
#	1 - CEROwrt-guest
#	2 - babel (on 2.4GHz)
#	3 - CEROwrt5
#	4 - CEROwrt-guest5
#	5 - babel (on 5GHz)

# === Assign channels for the wireless radios
# Set the channels for the wireless radios
# Radio0 choices are 1..11
# Radio1 choices are 36, 40, 44, 48, 149, 153, 157, 161, 165
#    The default HT40+ settings bond 36&40, 44&48, etc.
#    Choose 36 or 44 and it'll work fine
# echo 'Setting 2.4 & 5 GHz channels'
# uci set wireless.radio0.channel=6
# uci set wireless.radio1.channel=44

# === Assign the SSID's
# These are the default SSIDs for CeroWrt; no need to set again
# echo 'Setting SSIDs'
# uci set wireless.@wifi-iface[0].ssid=CEROwrt
# uci set wireless.@wifi-iface[1].ssid=CEROwrt-guest
# uci set wireless.@wifi-iface[3].ssid=CEROwrt5
# uci set wireless.@wifi-iface[4].ssid=CEROwrt-guest5

# === Assign the encryption/password ================
# Update the wifi password/security. To see all the wireless info:
#	uci show wireless
# The full list of encryption modes is at: (psk2 gives WPA2-PSK)
#	http://wiki.openwrt.org/doc/uci/wireless#wpa.modes
# Set WIFIPASSWD and the ENCRMODE, and then uncomment the remaining lines.
#
# echo 'Updating WiFi security information'
# WIFIPASSWD='Beatthebloat'
# ENCRMODE=psk2

# uci set wireless.@wifi-iface[0].key=$WIFIPASSWD
# uci set wireless.@wifi-iface[1].key=$WIFIPASSWD
# uci set wireless.@wifi-iface[3].key=$WIFIPASSWD
# uci set wireless.@wifi-iface[4].key=$WIFIPASSWD

# uci set wireless.@wifi-iface[0].encryption=$ENCRMODE
# uci set wireless.@wifi-iface[1].encryption=$ENCRMODE
# uci set wireless.@wifi-iface[3].encryption=$ENCRMODE
# uci set wireless.@wifi-iface[4].encryption=$ENCRMODE

# uci commit wireless
