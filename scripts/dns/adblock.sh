#!/usr/bin/env bash
# Block ads using the power of NXDOMAIN
# https://github.com/openwrt/packages/blob/openwrt-18.06/net/adblock/files/README.md
# NOTE there is also https://github.com/openwrt/packages/blob/master/net/simple-adblock/files/README.md
# but who, in this world of unauthorized access, would want the hacker next door
# to know they were installing packages with "simple" in the name? Frankly, this
# looks pretty simple to me.
# VARIBLES
# BLOCKLISTS:="adaway adguard bitcoin disconnect dshield hphosts malware malwarelist notracking openphish shalla spam404 sysctl ut_capitole whocares winspy winhelp yoyo"}
# WHITELIST:=(storage.googleapis.com)
# BLACKLIST:=()
# Note that BLOCKLISTS is not an array - the values map to UCI keys, so they won't have
# spaces. These values plus the defaults should not break anything.
# uci set adblock.${list}.enabled=0 to disable a list
# uci show adblock | awk -F. '/enabled/ { print $2 }' to list all the lists
# uci show adblock | awk -F= '/=source$/ { print substr($1, 9) }'
# uci show adblock | grep '=source$' | cut -d= -f1 | cut -b9-

set -e

## --- cURL and ca-bundle must be installed
opkg list-installed | grep -q ^ca-bundle || opkg install ca-bundle
opkg list-installed | grep -q ^curl || opkg install curl

## --- adblock is also necessary.
# coreutils-sort is used to do something like `cat /all/the/*.list | sort -u`
opkg install adblock luci-app-adblock coreutils-sort

## -- Set some global settings
uci batch <<EOF
set adblock.global.adb_enabled=1
set adblock.global.adb_dns='unbound'
set adblock.global.adb_fetchutil='curl'
set adblock.extra.adb_maxqueue=16
set adblock.extra.adb_nice=10
EOF

## -- Ensure all of the blocklists are enabled
echo "Enabling blocklists ${BLOCKLISTS:="adaway adguard bitcoin disconnect dshield hphosts malware malwarelist notracking openphish shalla spam404 sysctl ut_capitole whocares winspy winhelp yoyo"}"
for blocklist in $BLOCKLISTS; do
    uci set adblock.${blocklist}.enabled=1
done
uci commit adblock

## -- Whitelist some domains, maybe
: ${WHITELIST:=(storage.googleapis.com)}
if [ -n "${WHITELIST}" ]; then
    echo "Adding whitelisted domains..."
    (IFS=$'\n'; echo "${WHITELIST[*]}" > /etc/adblock/adblock.whitelist)
else
    echo "Skipping empty whitelist"
fi

## -- Blacklist some domains, maybe
: ${BLACKLIST:=()}
if [ -n "${BLACKLIST}" ]; then
    echo "Adding blacklisted domains..."
    (IFS=$'\n'; echo "${BLACKLIST[*]}" > /etc/adblock/adblock.blacklist)
else
    echo "Skipping empty blacklist"
fi

/etc/init.d/adblock restart
/etc/init.d/adblock enable

# The reload command updates our spam lists.
grep -q adblock /etc/crontabs/root || echo "0 4 * * *    /etc/init.d/adblock reload" >> /etc/crontabs/root
