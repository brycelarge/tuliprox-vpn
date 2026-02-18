#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/scripts/logging.sh
source /scripts/logging.sh

log "[OpenVPN NordVPN] fetching config files"

base_url="https://downloads.nordcdn.com/configs/archives/servers"
bundle="ovpn.zip"

# Clean existing configs (keep scripts) — only remove known NordVPN subdirs
find . -maxdepth 1 -type f ! -name '*.sh' -delete 2>/dev/null || true
rm -rf ./ovpn_udp ./ovpn_tcp 2>/dev/null || true

curl -fsSL --max-time 120 "${base_url}/${bundle}" -o openvpn.zip
unzip -q openvpn.zip
rm -f openvpn.zip

# NordVPN zip contains ovpn_udp/ and ovpn_tcp/ subdirs.
# Build list.txt with subdir-relative paths so validation can resolve by protocol.
: > list.txt
for subdir in ovpn_udp ovpn_tcp; do
    [ -d "${subdir}" ] || continue
    for cfg in "${subdir}"/*.ovpn; do
        [ -f "${cfg}" ] || continue
        echo "${cfg#./}" >> list.txt
    done
done
