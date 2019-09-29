#!/usr/bin/env bash
# Install and configure Privoxy to use AdBlockPlus Blocklist

opkg install privoxy

# TODO make /etc/config/firewall include a file that contains this
echo "Adding port 80 redirect"
echo >> /etc/config/firewall <<EOF
config redirect
        option proto 'tcp'
        option target 'DNAT'
        option dest 'lan'
        option _name 'Privoxy transparent-proxy for HTTP'
        option src 'lan'
        option dest_port '8118'
        option src_dport '80'
        option dest_ip '192.168.1.1'
        option src_dip '!192.168.1.1'

EOF

# This might error out installing sed
# Afterwards I had sed, but not sure where it came from
# Now BASH, that's nice to have!
declare -a PKGS
command -v wget || PKGS+=wget
command -v sed || PKGS+=sed
opkg install coreutils-install $PKGS[@]
# Install the AdBlocker blocklist in privoxy format
pushd /etc/privoxy
wget -v --no-check-certificate https://raw.github.com/Andrwe/privoxy-blocklist/master/privoxy-blocklist.sh
chmod +xv privoxy-blocklist.sh
sed -i.bak s/^SCRIPTCONF.*/SCRIPTCONF=\\/etc\\/privoxy\\/blocklist.conf/ privoxy-blocklist.sh
diff privoxy-blocklist.sh.bak privoxy-blocklist.sh

echo > /etc/privoxy/blocklist.conf <<'EOF'
# Config of privoxy-blocklist

# array of URL for AdblockPlus lists
#  for more sources just add it within the round brackets
URLS=(
"https://easylist-downloads.adblockplus.org/malwaredomains_full.txt"
"https://easylist-downloads.adblockplus.org/fanboy-social.txt"
"https://easylist-downloads.adblockplus.org/easyprivacy.txt"
"https://easylist-downloads.adblockplus.org/easylist.txt"
"https://easylist-downloads.adblockplus.org/easylistdutch.txt"
# "https://easylist-downloads.adblockplus.org/easylistdutch+easylist.txt"
)

# config for privoxy initscript providing PRIVOXY_CONF, PRIVOXY_USER and PRIVOXY_GROUP
INIT_CONF="/etc/conf.d/privoxy"

# !! if the config above doesn't exist set these variables here !!
# !! These values will be overwritten by INIT_CONF !!
PRIVOXY_USER="root"
PRIVOXY_GROUP="root"
PRIVOXY_CONF="/etc/privoxy/config"

# name for lock file (default: script name)
TMPNAME="$(basename ${0})"
# directory for temporary files
TMPDIR="/tmp/${TMPNAME}"

# Debug-level
#   -1 = quiet
#    0 = normal
#    1 = verbose
#    2 = more verbose (debugging)
#    3 = incredibly loud (function debugging)
DBG=0
EOF

# Test it out
echo "Updating blacklist..."
/etc/privoxy/privoxy-blocklist.sh

# Run it weekly
echo "Adding blacklist update cron"
echo "@weekly /etc/privoxy/privoxy-blocklist.sh" >> /etc/crontabs/root
touch /etc/crontabs/cron.update
grep -qF "root" /etc/crontabs/cron.update || echo "root\n" >> /etc/crontabs/cron.update

# https://www.privoxy.org/user-manual/config.html
# https://openwrt.org/docs/guide-user/services/proxy/privoxy
# http://blog.vanutsteen.nl/2014/01/05/installing-privoxy-with-adblock-filters-on-openwrt/
# TODO: Listen on guest network as well, permit access from correct networks only
PRV_ITEM="privoxy.privoxy"
uci batch <<EOF
set $PRV_ITEM.accept_intercepted_requests='1'
delete $PRV_ITEM.listen_address
add_list $PRV_ITEM.listen_address='192.168.1.1'
add_list $PRV_ITEM.listen_address='192.168.1.1'
delete $PRV_ITEM.permit_access
add_list $PRV_ITEM.permit_access='192.168.0.0/16'
set $PRV_ITEM.tolerate_pipelining='1'
set $PRV_ITEM.default_server_timeout=60
set $PRV_ITEM.connection_sharing=1
set $PRV_ITEM.socket_timeout=10
set $PRV_ITEM.trust_x_forwarded_for=1
set $PRV_ITEM.admin_address='me@example.com'
set $PRV_ITEM.proxy_info_url='https://example.com/'
set $PRV_ITEM.temporary_directory='/tmp/'
set $PRV_ITEM.forwarded_connect_retries='2'
add_list $PRV_ITEM.filterfile='malwaredomains_full.script.filter'
add_list $PRV_ITEM.filterfile='fanboy-social.script.filter'
add_list $PRV_ITEM.filterfile='easyprivacy.script.filter'
add_list $PRV_ITEM.filterfile='easylist.script.filter'
add_list $PRV_ITEM.filterfile='easylistdutch.script.filter'
add_list $PRV_ITEM.actionsfile='malwaredomains_full.script.action'
add_list $PRV_ITEM.actionsfile='fanboy-social.script.action'
add_list $PRV_ITEM.actionsfile='easyprivacy.script.action'
add_list $PRV_ITEM.actionsfile='easylist.script.action'
add_list $PRV_ITEM.actionsfile='easylistdutch.script.action'
EOF
uci commit

/etc/init.d/privoxy start
/etc/init.d/privoxy enable
