#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/scripts/logging.sh
source /scripts/logging.sh

log "[OpenVPN ProtonVPN] checking for config files"

# ProtonVPN does not provide a public anonymous config bundle.
# You must manually download your .ovpn files from the ProtonVPN dashboard
# and place them in /app/config/openvpn/protonvpn/ on the host volume.
#
# Steps:
#   1. Log in at https://account.proton.me/vpn/downloads
#   2. Under "OpenVPN configuration files", select your desired server(s)
#   3. Download the .ovpn file(s)
#   4. Place them in your host volume at: <config_volume>/openvpn/protonvpn/
#   5. Set OPENVPN_USERNAME and OPENVPN_PASSWORD to your ProtonVPN OpenVPN credentials
#      (these are separate from your Proton account credentials — find them at
#       https://account.proton.me/vpn/downloads under "OpenVPN / IKEv2 username")

if ! ls ./*.ovpn >/dev/null 2>&1; then
    log "[OpenVPN ProtonVPN] ERROR: no .ovpn files found"
    log "[OpenVPN ProtonVPN] Download your configs from: https://account.proton.me/vpn/downloads"
    log "[OpenVPN ProtonVPN] Place .ovpn files in your config volume at: openvpn/protonvpn/"
    exit 1
fi

log "[OpenVPN ProtonVPN] found $(ls ./*.ovpn | wc -l) config file(s)"

: > list.txt
for config_file in *.ovpn; do
    [ -f "${config_file}" ] || continue
    echo "$(basename -- "${config_file}")" >> list.txt
done
