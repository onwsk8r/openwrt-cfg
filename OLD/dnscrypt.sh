#!/usr/bin/env bash
# Install and configure DNSCrypt.
# Basically stolen directly from
# https://openwrt.org/docs/guide-user/services/dns/dnscrypt_dnsmasq_dnscrypt-proxy
# Resolver list can be found at
# https://github.com/openwrt/packages/blob/master/net/dnscrypt-proxy/files/dnscrypt-resolvers.csv

opkg update
opkg install dnsmasq dnscrypt-proxy luci-app-dnscrypt-proxy

# Configure DNSCrypt provider

# USE ventricle.us  d0wn-us-ns{1,2,4}  dnscrypt.ca-{1,2}
while uci -q delete dnscrypt-proxy.@dnscrypt-proxy[-1]; do :; done
uci set dnscrypt-proxy.dns6a="dnscrypt-proxy"
uci set dnscrypt-proxy.dns6a.address="[::1]"
uci set dnscrypt-proxy.dns6a.port="5353"
uci set dnscrypt-proxy.dns6a.resolver="dnscrypt.eu-dk-ipv6"
uci set dnscrypt-proxy.dns6b="dnscrypt-proxy"
uci set dnscrypt-proxy.dns6b.address="[::1]"
uci set dnscrypt-proxy.dns6b.port="5354"
uci set dnscrypt-proxy.dns6b.resolver="dnscrypt.eu-nl"
uci set dnscrypt-proxy.dnsa="dnscrypt-proxy"
uci set dnscrypt-proxy.dnsa.address="127.0.0.1"
uci set dnscrypt-proxy.dnsa.port="5355"
uci set dnscrypt-proxy.dnsa.resolver="dnscrypt.eu-dk"
uci set dnscrypt-proxy.dnsb="dnscrypt-proxy"
uci set dnscrypt-proxy.dnsb.address="127.0.0.1"
uci set dnscrypt-proxy.dnsb.port="5356"
uci set dnscrypt-proxy.dnsb.resolver="dnscrypt.nl-ns0"
uci commit dnscrypt-proxy
service dnscrypt-proxy restart

# Enable DNS encryption
DNSCRYPT_ID="0"
uci -q delete dhcp.@dnsmasq[0].server
while uci get dnscrypt-proxy.@dnscrypt-proxy[${DNSCRYPT_ID}] &>/dev/null
do
DNSCRYPT_ADDR="$(uci get dnscrypt-proxy.@dnscrypt-proxy[${DNSCRYPT_ID}].address)"
DNSCRYPT_PORT="$(uci get dnscrypt-proxy.@dnscrypt-proxy[${DNSCRYPT_ID}].port)"
DNSCRYPT_SERV="${DNSCRYPT_ADDR//[][]/}#${DNSCRYPT_PORT}"
uci add_list dhcp.@dnsmasq[0].server="${DNSCRYPT_SERV}"
let DNSCRYPT_ID++
done
uci commit dhcp
service dnsmasq restart

# Enforce DNS encryption for local system
uci set dhcp.@dnsmasq[0].localuse="1"

# Fetch DNS provider
source /lib/functions/network.sh
network_find_wan NET_IF
network_find_wan6 NET_IF6
network_get_dnsserver NET_DNS "${NET_IF}"
network_get_dnsserver NET_DNS6 "${NET_IF6}"

# Override DNS encryption for NTP provider
uci get system.ntp.server \
| sed -e "s/\s/\n/g" \
| sed -e "s/^[0-9]*\.//" \
| sort -u \
| while read NTP_DOMAIN
do
uci add_list dhcp.@dnsmasq[0].server="/${NTP_DOMAIN}/${NET_DNS%% *}"
uci add_list dhcp.@dnsmasq[0].server="/${NTP_DOMAIN}/${NET_DNS6%% *}"
done
uci commit dhcp
service dnsmasq restart
