
new_wifi() {
    DEVICE=${1:?new_wifi: Parameter 1 must be radio name}
    NETWORK=${2:?new_wifi: Parameter 2 must be interface name}
    SSID=${3:?new_wifi: Parameter 3 must be SSID}
    KEY=${4:?new_wifi: Parameter 4 must be PSK}

    section=$(uci add wireless wifi-iface)
    uci batch <<EOF
set wireless.${section}.device="${DEVICE}"
set wireless.${section}.mode="ap"
set wireless.${section}.ssid="${SSID}"
set wireless.${section}.encryption="psk2"
set wireless.${section}.key="${KEY}"
set wireless.${section}.wpa_disable_eapol_key_retries=1
set wireless.${section}.network="${NETWORK}"
EOF
    uci commit wireless
}

new_wds_master() {
    DEVICE=${1:?new_wds_master: Parameter 1 must be radio name}
    NETWORK=${2:?new_wds_master: Parameter 2 must be interface name}
    SSID=${3:?new_wds_master: Parameter 3 must be SSID}
    KEY=${4:?new_wds_master: Parameter 4 must be PSK}

    new_wifi "${DEVICE}" "${NETWORK}" "${SSID}" "${KEY}"
    uci set wireless.@wifi-iface[-1].wds=1
    uci commit wireless
}

new_wds_client() {
    DEVICE=${1:?new_wds_client: Parameter 1 must be radio name}
    NETWORK=${2:?new_wds_client: Parameter 2 must be interface name}
    SSID=${3:?new_wds_client: Parameter 3 must be SSID}
    KEY=${4:?new_wds_client: Parameter 4 must be PSK}

    new_wifi "${DEVICE}" "${NETWORK}" "${SSID}" "${KEY}"
    uci set wireless.@wifi-iface[-1].wds=1
    uci set wireless.@wifi-iface[-1].mode="sta"
    uci commit wireless

    new_wifi "${DEVICE}" "${NETWORK}" "${SSID}" "${KEY}"
}
