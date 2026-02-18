#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/scripts/logging.sh
source /scripts/logging.sh

log "[OpenVPN PIA] fetching config files"

declare -a CONFIG_URLS=("" "-tcp")
declare -a CONFIG_FOLDERS=("" "tcp")
BASE_URL="https://www.privateinternetaccess.com/openvpn/openvpn"

NUMBER_OF_CONFIG_TYPES=${#CONFIG_URLS[@]}

for (( i=1; i<${NUMBER_OF_CONFIG_TYPES}+1; i++ )); do
    REQUEST_URL="${BASE_URL}${CONFIG_URLS[$i-1]}.zip"

    if [ -n "${CONFIG_FOLDERS[$i-1]}" ]; then
        mkdir -p "${CONFIG_FOLDERS[$i-1]}"
        cd "${CONFIG_FOLDERS[$i-1]}"
    fi

    curl -kL "${REQUEST_URL}" -o openvpn.zip
    unzip -j openvpn.zip
    rm -f openvpn.zip

    folder_with_escaped_slash=""
    if [ -n "${CONFIG_FOLDERS[$i-1]}" ]; then
        folder_with_escaped_slash="${CONFIG_FOLDERS[$i-1]}\/"
    fi

    : > list.txt
    for config_file in *.ovpn; do
        [ -f "${config_file}" ] || continue
        echo "$(basename -- "${config_file}")" >> list.txt
    done

    if [ -n "${CONFIG_FOLDERS[$i-1]}" ]; then
        cd ..
    fi
done
