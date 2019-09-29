#!/usr/bin/env sh
# Update OS, install stuff, set hostname
# Variables:
# HOSTNAME must be set

## Update package lists and install any updates
opkg update
for pkg in $(opkg list-upgradable | cut -d' ' -f1); do
    opkg upgrade $pkg
done

## Install some basic tools...
opkg install bash curl ca-bundle nmap tcpdump

## Set the Hostname
test -z "$HOSTNAME" && echo "Hostname must be set. Exiting." && exit 1
uci set system.@system[0].hostname="$HOSTNAME"
uci commit system
