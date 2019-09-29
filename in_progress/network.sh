#!/usr/bin/env bash
# Configure basic networking.
# This script creates two new VLANs, for a total of 3.
# It will set the IP and subnet mask and configure DHCP
# on all three networks, and configure a basic firewall
# on the new ones. It has functions that do these things.

# TODO: A little bit of firewall on the main network, maybe?

## ===== Create a new network
# Usage: new_network <name> <addr> [mask]
# name = arbitrary name
# addr = address for the interface (ie 192.168.0.1)
# mask = 255.255.255.0 by default
# TODO: Change this to use $(ipcalc.sh 192.168.1.1/24) (try it)
function new_network() {
    NAME=$1
    ADDR=$2
    MASK=${3:-"255.255.255.0"}

    uci batch <<- EOF
set network.${NAME}=interface
set network.${NAME}.ifname=$NAME
set network.${NAME}.proto=static
set network.${NAME}.ipaddr=$ADDR
set network.${NAME}.netmask=$MASK
set network.${NAME}.ip6assign='60'
EOF
}

## ===== Create a new DHCP server
# https://openwrt.org/docs/guide-user/base-system/dhcp
# Usage: new_dhcp <name> [leasetime] [start] [end]
# name = arbitrary name, must identify a network
# leasetime = time string. Default 12h
# start = Start address. Default 3
# limit = Limit. Default 250.
function new_dhcp() {
    NAME=$1
    IFACE=$2
    LEASETIME=${3:-"12h"}
    START=${4:-100}
    END=${5:-150}

    uci batch <<- EOF
set dhcp.${NAME}=dhcp
set dhcp.${NAME}.interface=$IFACE
set dhcp.${NAME}.start=$START
set dhcp.${NAME}.leasetime=$LEASETIME
set dhcp.${NAME}.limit=$LIMIT
set dhcp.${NAME}.dhcpv6=server
set dhcp.${NAME}.ra=server
EOF
}

function new_dnsmasq() {
    IDX=$1
    IFACE=$2
    USEDNSCRYPT=${3:-no}
    uci batch <<- EOF
set dhcp.@dnsmasq[${IDX}].authoritative=1
set dhcp.@dnsmasq[${IDX}].bogusnxdomain=198.105.244.228
set dhcp.@dnsmasq[${IDX}].cachelocal=1 # default
set dhcp.@dnsmasq[${IDX}].cachesize=150 # default
set dhcp.@dnsmasq[${IDX}].dbus=0 # default
set dhcp.@dnsmasq[${IDX}].dhcpleasemax=150 # default
set dhcp.@dnsmasq[${IDX}].dhcpforwardmax=150 # default
set dhcp.@dnsmasq[${IDX}].domainneeded=1 # default
set dhcp.@dnsmasq[${IDX}].ednspacketmax=1280 # default
set dhcp.@dnsmasq[${IDX}].dnssec=1 # This might break things
set dhcp.@dnsmasq[${IDX}].dnsseccheckunsigned=1 # if the clock gets off
set dhcp.@dnsmasq[${IDX}].expandhosts=1 # default
set dhcp.@dnsmasq[${IDX}].interface=$IFACE
set dhcp.@dnsmasq[${IDX}].nonwildcard=1 # maybe
set dhcp.@dnsmasq[${IDX}].rebind_protection=1
set dhcp.@dnsmasq[${IDX}].localservice=1 # default
set dhcp.@dnsmasq[${IDX}].logqueries=1
# set dhcp.@dnsmasq[${IDX}].leasefile=/tmp/dhcp$IDX
# FIXME need to add the other router as a DNS server
EOF
    # Use dnscrypt
    test "$USEDNSCRYPT" -eq "yes" && uci batch <<- EOF
delete dhcp.@dnsmasq[${IDX}].resolvfile
set dhcp.@dnsmasq[${IDX}].noresolv=1
delete dhcp.@dnsmasq[${IDX}].server
add_list dhcp.@dnsmasq[${IDX}].server='127.0.0.1#5353'
add_list dhcp.@dnsmasq[${IDX}].server='/pool.ntp.org/208.67.222.222'
set dhcp.@dnsmasq[${IDX}].strictorder=1
EOF
}

## ===== Enable Local DNS resoution with mDNS
# mDNS allows devices to look each other up by name
# This enables mDNS lookups on the LAN (br-lan) interface
opkg install avahi-daemon
echo 'Enabling mDNS on LAN interface'
echo "Warning, figure out wtf this did"
sed -i.bak '/use-iff/ a \
allow-interfaces=br-lan \
enable-dbus=no ' /etc/avahi/avahi-daemon.conf
sed -i '/enable-reflector/s/no/yes/' /etc/avahi/avahi-daemon.conf
/etc/init.d/avahi-daemon enable
# /etc/init.d/avahi-daemon start

uci clear dhcp
new_dhcp maglev


uci set dhcp.@dnsmasq[0].add_local_domain=1
uci set dhcp.@dnsmasq[0].add_local_hostname=1
uci set dhcp.@dnsmasq[0].local='/bhaze.int/'
uci set dhcp.@dnsmasq[0].domain='bhaze.int'
uci set dhcp.@dnsmasq[0].boguspriv=1
uci set dhcp.@dnsmasq[0].readethers=1
# nohosts=1
uci commit dhcp


## ===== Configure local network
# https://superuser.com/questions/809290/is-it-possible-to-force-dns-for-certain-devices-with-iptables
# iptables -t nat -A PREROUTING -i br0 -p udp --dport 53 -j DNAT --to 127.0.0.1


cat dnscrypt-resolvers.csv| awk -v FPAT='[^,]*|"[^"]+"' 'BEGIN { FS="," } /ipv6/ { if ($8 == "yes") print $1 + }'
