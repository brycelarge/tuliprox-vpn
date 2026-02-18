#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/scripts/logging.sh
source /scripts/logging.sh

log "[OpenVPN IPVanish] fetching config files"

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
    echo "$(basename -- "${config_file}")" >> list.txt

    # Ensure credentials path points to our runtime config dir
    sed -i "s|auth-user-pass.*|auth-user-pass /app/config/openvpn/ipvanish-openvpn-credentials.txt|g" "${config_file}" || true
done
