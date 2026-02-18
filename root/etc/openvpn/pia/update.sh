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

        sed -i "s|auth-user-pass.*|auth-user-pass /app/config/openvpn/pia-openvpn-credentials.txt|g" "${config_file}" || true
        sed -i "s|ca ca\.rsa\.\([0-9]*\)\.crt|ca /app/config/openvpn/pia/${folder_with_escaped_slash}ca\.rsa\.\1\.crt|g" "${config_file}" || true
        sed -i "s|crl-verify crl\.rsa\.\([0-9]*\)\.pem|crl-verify /app/config/openvpn/pia/${folder_with_escaped_slash}crl\.rsa\.\1\.pem|g" "${config_file}" || true
    done

    if [ -n "${CONFIG_FOLDERS[$i-1]}" ]; then
        cd ..
    fi
done
