#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/scripts/logging.sh
source /scripts/logging.sh

log "[OpenVPN Surfshark] fetching config files"

REQUEST_URL="https://my.surfshark.com/vpn/api/v1/server/configurations"

curl -skL "${REQUEST_URL}" -o openvpn.zip
unzip -jq openvpn.zip
rm -f openvpn.zip

: > list.txt
for config_file in *.ovpn; do
    [ -f "${config_file}" ] || continue
    echo "$(basename -- "${config_file}")" >> list.txt
done
