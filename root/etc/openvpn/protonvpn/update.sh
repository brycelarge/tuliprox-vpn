#!/usr/bin/env bash
set -euo pipefail

echo "[OpenVPN ProtonVPN] preparing config files" | ts '%Y-%m-%d %H:%M:%S'

# ProtonVPN does not provide an anonymous public bundle like some providers.
# Expect user-provided configs to be mounted at /app/config/openvpn/protonvpn.

src_dir="/app/config/openvpn/protonvpn"

# If the script is called from elsewhere
cd "${0%/*}"

if [ ! -d "${src_dir}" ]; then
    echo "[OpenVPN ProtonVPN] expected ${src_dir} to exist (mount your ProtonVPN .ovpn files there)" | ts '%Y-%m-%d %H:%M:%S'
    exit 1
fi

# If user already staged configs, nothing to do
if ls -1 "${src_dir}"/*.ovpn >/dev/null 2>&1; then
    # Clean existing configs in provider dir (keep scripts)
    find . -type f ! -name '*.sh' -delete

    # Copy all protonvpn config artifacts (ovpn, crt, etc.)
    cp -R "${src_dir}/." .

    : > list.txt
    for config_file in *.ovpn; do
        [ -f "${config_file}" ] || continue
        echo "[OpenVPN ProtonVPN] cleaning ${config_file}" | ts '%Y-%m-%d %H:%M:%S'
        echo "$(basename -- "${config_file}")" >> list.txt

        /scripts/openvpn-config-clean.sh "${config_file}" || true

        sed -i "s|^auth-user-pass.*|auth-user-pass /app/config/openvpn/protonvpn-openvpn-credentials.txt|" "${config_file}" || true
    done
else
    echo "[OpenVPN ProtonVPN] no .ovpn files found in ${src_dir}" | ts '%Y-%m-%d %H:%M:%S'
    echo "[OpenVPN ProtonVPN] download configs from your Proton account and place them in ${src_dir}" | ts '%Y-%m-%d %H:%M:%S'
    exit 1
fi
