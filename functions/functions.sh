#/usr/bin/env bash

set -e

if [ -z "${BASE_DIR}" ]; then
    echo "functions.sh: BASE_DIR must be set"
    exit 1
fi

for f in ${BASE_DIR}/functions/_*.sh; do
    source "${f}"
done

add_network() {
    NAME=${1:?add_network: Parameter 1 must be name}
    IP=${2:?add_network: Parameter 2 must be IP}

    vlan_bridge_add "${NAME}"
    network_static "${NAME}" "${IP}"
    firewall_add_zone "${NAME}"

    uci commit network
    uci commit dhcp
    uci commit firewall
    command -v unbound &>/dev/null && uci commit unbound
}

add_master_network() {
    NAME=${1:?add_master_network: Parameter 1 must be name}
    IP=${2:?add_master_network: Parameter 2 must be IP}

    add_network "${NAME}" "${IP}"
    uci set network.${NAME}.stp=1
    uci commit network

    dhcp_add "${NAME}"
    uci commit dhcp
    firewall_add_forward "${NAME}"
    uci commit firewall
}

add_client_network() {
    NAME=${1:?add_client_network: Parameter 1 must be name}
    IP=${2:?add_master_network: Parameter 2 must be IP}

    add_network "${NAME}" "${IP}"
    uci set network.${NAME}.stp=1
    uci commit network
}
