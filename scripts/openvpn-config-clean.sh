#!/usr/bin/env bash
set -euo pipefail

file="$1"

/scripts/dos2unix.sh "${file}" || true

# Remove up/down resolv-conf script calls
sed -i "/update-resolv-conf/d" "${file}" || true

# Normalize tcp proto
sed -i "s/^proto\stcp$/proto tcp-client/g" "${file}" || true

# Remove deprecated/host-specific options
sed -i '/^reneg-sec.*/d' "${file}" || true
sed -i '/^block-outside-dns/d' "${file}" || true
sed -i '/^route-method exe/d' "${file}" || true
sed -i '/^service\s.*/d' "${file}" || true

# Ensure dev is a stable tun name (tun)
vpn_device_type="$(grep -E -m1 '^dev\s+' "${file}" | awk '{print $2}' | tr -d '\r' || true)"
if [ -z "${vpn_device_type}" ]; then
    echo "[openvpn-config-clean] WARNING: no 'dev' line found in ${file}, skipping dev normalisation" >&2
fi

sed -i "s/^dev\s.*/dev ${vpn_device_type}/g" "${file}" || true
