#!/usr/bin/env bash
set -euo pipefail

echo "[OpenVPN Surfshark] grab config files" | ts '%Y-%m-%d %H:%M:%S'

REQUEST_URL="https://my.surfshark.com/vpn/api/v1/server/configurations"

# If the script is called from elsewhere
cd "${0%/*}"

curl -skL "${REQUEST_URL}" -o openvpn.zip
unzip -jq openvpn.zip
rm -f openvpn.zip

: > list.txt
for config_file in *.ovpn; do
    [ -f "${config_file}" ] || continue
    echo "[OpenVPN Surfshark] cleaning ${config_file}" | ts '%Y-%m-%d %H:%M:%S'
    echo "$(basename -- "${config_file}")" >> list.txt

    /scripts/openvpn-config-clean.sh "${config_file}" || true

    sed -i "s/AES-256-CBC/AES-128-GCM/g" "${config_file}" || true
    sed -i "s|auth-user-pass.*|auth-user-pass /app/config/openvpn/surfshark-openvpn-credentials.txt|g" "${config_file}" || true
done
