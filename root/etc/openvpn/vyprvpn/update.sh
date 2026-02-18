#!/usr/bin/env bash
set -euo pipefail

echo "[OpenVPN VyprVPN] grab config files" | ts '%Y-%m-%d %H:%M:%S'

cd "${0%/*}"

REQUEST_URL="https://support.vyprvpn.com/hc/article_attachments/360052617332/Vypr_OpenVPN_20200320.zip"

curl -skL "${REQUEST_URL}" -o openvpn.zip
unzip -jq openvpn.zip
rm -f openvpn.zip

# Extract nested paths if present
if [ -d "GF_OpenVPN_20200320/OpenVPN160" ]; then
    mv GF_OpenVPN_20200320/OpenVPN160/*.ovpn ./
    rm -rf GF_OpenVPN_20200320/OpenVPN160 GF_OpenVPN_20200320/OpenVPN256
fi

: > list.txt
for config_file in *.ovpn; do
    [ -f "${config_file}" ] || continue
    echo "[OpenVPN VyprVPN] cleaning ${config_file}" | ts '%Y-%m-%d %H:%M:%S'
    echo "$(basename -- "${config_file}")" >> list.txt

    /scripts/openvpn-config-clean.sh "${config_file}" || true

    sed -i "s|auth-user-pass.*|auth-user-pass /app/config/openvpn/vyprvpn-openvpn-credentials.txt|g" "${config_file}" || true
done
