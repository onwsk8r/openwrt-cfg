#!/usr/bin/env bash
# Install avahi-daemon to handle mDNS across networks
# https://linux.die.net/man/5/avahi-daemon.conf
# VARIABLES
# AVAHI_IFS:="br-lan" - comma separated list of interfaces to listen on
set -e

opkg install avahi-daemon

# This line breaks registering address records
# -e '/\[publish\]/a disable-publishing=yes'
sed -i \
    -e '/\[server\]/a allow-interfaces='"${AVAHI_IFS:-br-lan}" \
    -e '/enable-reflector/s/no/yes/' \
    -e '/check-response-ttl/s/yes/no/' /etc/avahi/avahi-daemon.conf
/etc/init.d/avahi-daemon restart
/etc/init.d/avahi-daemon enable
