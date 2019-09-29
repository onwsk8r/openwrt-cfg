#!/usr/bin/env bash
# Install and configure Unbound, and replace DNSMasq with odhcpd
# This also configures the LAN network to use SLAAC for IPv6.
# https://openwrt.org/docs/guide-user/services/dns/dot_unbound
# https://wiki.archlinux.org/index.php/unbound
# https://openwrt.org/docs/guide-user/services/dns/unbound
# https://github.com/openwrt/packages/blob/openwrt-18.06/net/unbound/files/README.md
# https://nlnetlabs.nl/documentation/unbound
# Additional relevant documentation can be found at:
# https://openwrt.org/docs/guide-user/base-system/dhcp_configuration
# https://openwrt.org/docs/guide-user/base-system/dhcp
# Note that the odhcpd docs, linked from the dhcp_configuration page, show
# different options than for dnsmasq - no dhcp_option, for example.
# VARIBLES
# ${LOCAL_DOMAIN:-openwrt} - resolve networked hosts (and this router) under this domain
# FORCE_DNS - redirect 53/UDP and 853/TCP to this host unless this var is empty (="")

set -e

## --- Install the unbound things
opkg install unbound unbound-control unbound-host luci-app-unbound

## --- Ship our configs
cd $(dirname $(readlink -f $0))
<unbound_ext.conf cat >/etc/unbound/unbound_ext.conf
<unbound_srv.conf cat >/etc/unbound/unbound_srv.conf

## --- No need for DNSMasq (_DNS_ masq, dys?) - odhcpd will do the trick
# Also, configure the LAN DHCP to use SLAAC. We can't all have huge prefixes...
opkg remove dnsmasq odhcpd-ipv6only
opkg install odhcpd
uci -q delete dhcp.@dnsmasq[0]
uci batch <<EOF
set dhcp.odhcpd.maindhcp=1
set dhcp.odhcpd.leasefile='/var/lib/odhcpd/dhcp.leases'
set dhcp.odhcpd.leasetrigger='/usr/lib/unbound/odhcpd.sh'
set dhcp.lan.dhcpv4='server'
set dhcp.lan.dhcpv6='disabled'
set dhcp.lan.ra='server'
set dhcp.lan.ndp='server'
set dhcp.lan.leasetime='1h'
set network.lan.ip6assign=64
EOF
uci commit dhcp
uci commit network.lan

# This default setup gives local DNS/rDNS resolution, configures
# some basic (read: lock your doors) security, configures resource
# usage for a reasonably modern router and a reasonably fast internet
# and enables DNSSEC.
# NOTE: the `unbound_control` setting does not seem to work as intended
# Setting to 1 does not actually enable it in the generated config file,
# but the default setup allows unencrypted connections, so it does
# actually work.
uci batch <<EOF
set unbound.@unbound[-1].add_local_fqdn=3
set unbound.@unbound[-1].add_wan_fqdn=1
set unbound.@unbound[-1].dhcp_link='odhcpd'
set unbound.@unbound[-1].domain='${LOCAL_DOMAIN:-openwrt}'
set unbound.@unbound[-1].domain_type='static'
set unbound.@unbound[-1].extended_luci=1
set unbound.@unbound[-1].extended_stats=1
set unbound.@unbound[-1].hide_binddata=1
set unbound.@unbound[-1].localservice=1
set unbound.@unbound[-1].protocol='ip6_prefer'
set unbound.@unbound[-1].rebind_localhost=1
set unbound.@unbound[-1].rebind_protection=2
set unbound.@unbound[-1].recursion='aggressive'
set unbound.@unbound[-1].resource='medium'
set unbound.@unbound[-1].unbound_control=1
set unbound.@unbound[-1].validator=1
EOF
uci commit unbound

# And get everything running
/etc/init.d/unbound restart
/etc/init.d/odhcpd restart
/etc/init.d/unbound enable
/etc/init.d/odhcpd enable

# Force DNS queries (except DoH) to be served from this machine
if [ -z "${FORCE_DNS+x}" ]; then
    echo "FORCE_DNS is unset. Forcing DNS."
    FORCE_DNS=1
fi

if [ -n "${FORCE_DNS}" ]; then
    grep -q "dport 53 -j DNAT" /etc/firewall.user || echo "iptables -t nat -A PREROUTING -i br-+ -p udp --dport 53 -j DNAT --to 127.0.0.1" >> /etc/firewall.user
    grep -q "dport 853 -j DNAT" /etc/firewall.user || echo "iptables -t nat -A PREROUTING -i br-+ -p tcp --dport 853 -j DNAT --to 127.0.0.1" >> /etc/firewall.user
    /etc/init.d/firewall reload
fi
