#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/scripts/logging.sh
source /scripts/logging.sh

log "[OpenVPN VyprVPN] fetching config files"

# VyprVPN no longer provides a public config bundle via a stable URL.
# Try the last known URL; if it fails, fall back to user-supplied configs.
REQUEST_URL="https://support.vyprvpn.com/hc/article_attachments/360052617332/Vypr_OpenVPN_20200320.zip"

if curl -fskL --max-time 30 "${REQUEST_URL}" -o openvpn.zip 2>/dev/null; then
    log "[OpenVPN VyprVPN] downloaded config bundle"
    unzip -jq openvpn.zip
    rm -f openvpn.zip

    # Extract nested paths if present
    if [ -d "GF_OpenVPN_20200320/OpenVPN160" ]; then
        mv GF_OpenVPN_20200320/OpenVPN160/*.ovpn ./
        rm -rf GF_OpenVPN_20200320/OpenVPN160 GF_OpenVPN_20200320/OpenVPN256
    fi
else
    rm -f openvpn.zip 2>/dev/null || true
    log "[OpenVPN VyprVPN] WARNING: could not download config bundle (URL may be stale)"
    log "[OpenVPN VyprVPN] To use VyprVPN, manually place your .ovpn files in:"
    log "[OpenVPN VyprVPN]   /app/config/openvpn/vyprvpn/"
    log "[OpenVPN VyprVPN] Download configs from: https://www.vyprvpn.com/download"
    # Only exit 1 if there are no existing configs to fall back on
    if ! ls ./*.ovpn >/dev/null 2>&1; then
        exit 1
    fi
    log "[OpenVPN VyprVPN] found existing .ovpn files, continuing"
fi

: > list.txt
for config_file in *.ovpn; do
    [ -f "${config_file}" ] || continue
    echo "$(basename -- "${config_file}")" >> list.txt
done
