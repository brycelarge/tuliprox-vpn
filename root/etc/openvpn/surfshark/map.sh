#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/scripts/logging.sh
source /scripts/logging.sh

# This is a lightweight replacement for the sqlite mapping used in xteve-vpn.
# It writes a JSON mapping file to /app/config/openvpn/surfshark_map.json

out_file="${SURFSHARK_MAP_FILE:-/app/config/openvpn/surfshark_map.json}"
mkdir -p "$(dirname "${out_file}")"

clusters_json="$(curl -s "https://my.surfshark.com/vpn/api/v1/server/clusters")"

# Format: {"za_johannesburg":"za-jnb.prod.surfshark.com", ...}
# shellcheck disable=SC2016
printf '%s' "${clusters_json}" | jq -r '
  .[]
  | select(.countryCode != null and .location != null and .connectionName != null)
  | [((.countryCode + "_" + .location) | ascii_downcase), .connectionName]
  | @tsv
' | jq -Rn '
  [inputs | split("\t") | {key: .[0], value: .[1]}]
  | reduce .[] as $i ({}; .[$i.key] = $i.value)
' > "${out_file}"

log "[Surfshark] wrote server mapping to ${out_file}"
