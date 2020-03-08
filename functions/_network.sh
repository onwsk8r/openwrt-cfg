
echo "Using ${CPU_IFACE:=eth0} as CPU interface for VLANS"

bridge_add() {
    NAME=${1:?bridge_add: Parameter 1 must be name}
    IFACE=${2:?bridge_add: Parameter 2 must be interface}

    uci batch <<EOF
set network.${NAME}=interface
set network.${NAME}.ifname='${IFACE}'
set network.${NAME}.type='bridge'
set network.${NAME}.proto='dhcp'
set network.${NAME}.igmp_snooping=1
EOF

    if $(command -v unbound &>/dev/null); then
        uci add_list unbound.@unbound[-1].rebind_interface='${NAME}'
        uci add_list unbound.@unbound[-1].trigger_interface='${NAME}'
    fi
}

network_static() {
    NAME=${1:?network_static: Parameter 1 must be name}
    IP=${2:?network_static: Parameter 2 must be IP}
    SUBNET=${3:-255.255.255.0}
    IP6ASSIGN=${4:-64}

    uci batch <<EOF
set network.${NAME}.proto='static'
set network.${NAME}.ipaddr='${IP}'
set network.${NAME}.netmask='${SUBNET}'
set network.${NAME}.ip6assign='${IP6ASSIGN}'
EOF
}

vlan_bridge_add() {
    NAME=${1:?vlan_bridge_add: Parameter 1 must be name}
    DEVICE=${2:-switch0}

    vid=$(($(uci show network | grep -c "=switch_vlan")+1))
    section=$(uci add network switch_vlan)
    uci batch <<EOF
set network.${section}.device='${DEVICE}'
set network.${section}.vlan=${vid}
set network.${section}.ports='5t'
set network.${section}.vid=${vid}
EOF
    bridge_add "${NAME}" "${CPU_IFACE}.${vid}" # TODO get proper 'eth0'
}

dhcp_add() {
    NAME=${1:?dhcp_add: Parameter 1 must be interface name}
    uci batch <<EOF
set dhcp.${NAME}=dhcp
set dhcp.${NAME}.interface='${NAME}'
set dhcp.${NAME}.dhcpv4='server'
set dhcp.${NAME}.dhcpv6='server'
set dhcp.${NAME}.start=100
set dhcp.${NAME}.limit=150
set dhcp.${NAME}.leasetime='1h'
EOF
}
