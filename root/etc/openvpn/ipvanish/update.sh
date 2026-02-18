#!/usr/bin/env bash
set -euo pipefail

echo "[OpenVPN IPVanish] grab config files" | ts '%Y-%m-%d %H:%M:%S'

base_url="https://configs.ipvanish.com/configs"
bundle="configs.zip"

# If the script is called from elsewhere
cd "${0%/*}"

# Clean existing configs (keep scripts)
find . -type f ! -name '*.sh' -delete

curl -sSL "${base_url}/${bundle}" -o openvpn.zip
unzip -qjo openvpn.zip
rm -f openvpn.zip

: > list.txt
for config_file in *.ovpn; do
    [ -f "${config_file}" ] || continue
    echo "[OpenVPN IPVanish] cleaning ${config_file}" | ts '%Y-%m-%d %H:%M:%S'
    echo "$(basename -- "${config_file}")" >> list.txt

    /scripts/openvpn-config-clean.sh "${config_file}" || true

    # Ensure credentials path points to our runtime config dir
    sed -i "s|auth-user-pass.*|auth-user-pass /app/config/openvpn/ipvanish-openvpn-credentials.txt|g" "${config_file}" || true
done
