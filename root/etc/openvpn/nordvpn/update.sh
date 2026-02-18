#!/usr/bin/env bash
set -euo pipefail

echo "[OpenVPN NordVPN] grab config files" | ts '%Y-%m-%d %H:%M:%S'

base_url="https://downloads.nordcdn.com/configs/archives/servers"
bundle="ovpn.zip"

# If the script is called from elsewhere
cd "${0%/*}"

# Clean existing configs (keep scripts)
find . -type f ! -name '*.sh' -delete
find . -type d ! -path . -exec rm -rf {} + 2>/dev/null || true

curl -sSL "${base_url}/${bundle}" -o openvpn.zip
unzip -q openvpn.zip
rm -f openvpn.zip

# NordVPN zip typically contains ovpn_udp/ and ovpn_tcp/
# Build a flat list.txt of available configs
: > list.txt
find . -type f -name '*.ovpn' | while read -r cfg; do
    echo "$(basename -- "${cfg}")" >> list.txt

done

# Clean and adjust configs in-place
find . -type f -name '*.ovpn' | while read -r cfg; do
    echo "[OpenVPN NordVPN] cleaning $(basename -- "${cfg}")" | ts '%Y-%m-%d %H:%M:%S'

    /scripts/openvpn-config-clean.sh "${cfg}" || true

    # ensure cipher/data-ciphers compatible with modern OpenVPN
    if grep -q '^cipher AES-256-CBC' "${cfg}"; then
        sed -i -e 's/^cipher AES-256-CBC$/cipher AES-256-GCM\ndata-ciphers AES-256-GCM/' "${cfg}" || true
    fi

    # Ensure credentials path points to our runtime config dir
    sed -i "s|^auth-user-pass.*|auth-user-pass /app/config/openvpn/nordvpn-openvpn-credentials.txt|" "${cfg}" || true

done
