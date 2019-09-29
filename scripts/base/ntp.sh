#!/usr/bin/env sh
# Enable default NTP client and set NTP server
# https://openwrt.org/docs/guide-user/advanced/ntp_configuration
# Variables:
# TIMEZONE:="CST6CDT,M3.2.0,M11.1.0"
# ZONENAME:="America/Chicago"
# NTP_SERVER:-us.pool.ntp.org

echo "Setting timezone to ${TIMEZONE:="CST6CDT,M3.2.0,M11.1.0"}"
uci set system.@system[0].timezone="$TIMEZONE"
echo "Setting zone name to ${ZONENAME:="America/Chicago"}"
uci set system.@system[0].zonename="${ZONENAME}"
uci commit system

echo "Configuring NTP servers and starting server and client..."
TARGET="system.ntp"
uci batch <<EOF
set $TARGET.enabled=1
set $TARGET.server="${NTP_SERVER:-us.pool.ntp.org}"
EOF
uci commit $TARGET
