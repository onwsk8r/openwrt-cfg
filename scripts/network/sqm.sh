#!/usr/bin/env sh
# Configure SQM for faster interneting
# https://openwrt.org/docs/guide-user/network/traffic-shaping/sqm
# VARIABLES
# ${DOWNSPEED:-200000} 90% or so of your download bandwidth
# ${UPSPEED:-200000} 90% or so of your upload bandwidth

set -e

opkg install sqm-scripts luci-app-sqm

TARGET="sqm.$(uci show sqm | tail -1 | cut -d. -f2)"
uci batch <<EOF
set $TARGET.enabled=1
set $TARGET.download=${DOWNSPEED:-200000}
set $TARGET.upload=${UPSPEED:-20000}
set $TARGET.verbosity='5'
set $TARGET.qdisc='cake'
set $TARGET.script='piece_of_cake.qos'
set $TARGET.linklayer='ethernet'
set $TARGET.overhead='22'
EOF
uci commit $TARGET

/etc/init.d/sqm start
/etc/init.d/sqm enable
