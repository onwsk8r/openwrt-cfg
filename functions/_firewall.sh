firewall_add_zone() {
    NAME=${1:?firewall_add_zone: Parameter 1 must be interface name}
    section=$(uci add firewall zone)
    uci batch <<EOF
set firewall.${section}.name='${NAME}'
set firewall.${section}.input='ACCEPT'
set firewall.${section}.output='ACCEPT'
set firewall.${section}.forward='ACCEPT'
set firewall.${section}.network='${NAME}'
EOF
}

firewall_add_forward() {
    FROM=${1:?firewall_add_forward: Parameter 1 must be zone name}
    TO=${2:-wan}
    section=$(uci add firewall forwarding)
    uci batch <<EOF
set firewall.${section}.src='${FROM}'
set firewall.${section}.dest='${TO}'
EOF
}
