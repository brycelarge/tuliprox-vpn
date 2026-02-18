#!/usr/bin/env bash
set -euo pipefail

# Outputs OPENVPN_CONFIG_FILE and OPENVPN_AUTH_FILE via stdout as KEY=VALUE lines.

# shellcheck source=/scripts/logging.sh
source /scripts/logging.sh

# Redirect log output to stderr so stdout stays clean for KEY=VALUE output
log() { echo "$*" | ts '%Y-%m-%d %H:%M:%S' >&2; }
debug_log() { if [ "${DEBUG:-false}" = "true" ]; then log "DEBUG: $*"; fi; }

if [ "${VPN_ENABLED:-false}" != "true" ]; then
    echo "VPN_ENABLED=false"
    exit 0
fi

vpn_dir="${VPN_DIR:-/app/config/openvpn}"
provider="${OPENVPN_PROVIDER:-CUSTOM}"
provider_lc="$(echo "${provider}" | tr '[:upper:]' '[:lower:]')"

protocol_lc="$(echo "${OPENVPN_PROTOCOL:-udp}" | tr '[:upper:]' '[:lower:]')"

config_name="${OPENVPN_CONFIG:-}"

mkdir -p "${vpn_dir}"

# Resolve config file
config_file=""

if [ "${provider_lc}" = "custom" ]; then
    if [ -n "${config_name}" ] && [ -f "${vpn_dir}/${config_name}" ]; then
        config_file="${vpn_dir}/${config_name}"
    elif [ -n "${config_name}" ] && [ -f "${vpn_dir}/${config_name}.ovpn" ]; then
        config_file="${vpn_dir}/${config_name}.ovpn"
    else
        config_file="$(find "${vpn_dir}" -maxdepth 1 -type f -name '*.ovpn' -print -quit || true)"
    fi
else
    # Provider configs are staged under /app/config/openvpn/<provider> by init-openvpn-config
    provider_dir="${vpn_dir}/${provider_lc}"
    if [ ! -d "${provider_dir}" ]; then
        log "[OpenVPN] OPENVPN_PROVIDER directory not found: ${provider_dir}"
        exit 1
    fi

    if [ -z "${config_name}" ]; then
        # NordVPN stores configs in protocol-specific subdirs
        if [ "${provider_lc}" = "nordvpn" ]; then
            nord_subdir="${provider_dir}/ovpn_${protocol_lc}"
            if [ -d "${nord_subdir}" ]; then
                config_file="$(find "${nord_subdir}" -type f -name '*.ovpn' -print -quit || true)"
            fi
        fi
        # Fall back to any .ovpn in the provider dir (recursive for NordVPN subdirs)
        if [ -z "${config_file}" ]; then
            config_file="$(find "${provider_dir}" -type f -name '*.ovpn' -print -quit || true)"
        fi
    else
        # allow specifying without .ovpn and with or without _udp/_tcp suffix
        name_base="$(echo "${config_name}" | sed 's/\.ovpn$//')"

        if [ -f "${provider_dir}/${name_base}.ovpn" ]; then
            config_file="${provider_dir}/${name_base}.ovpn"
        elif [ -f "${provider_dir}/${name_base}_${protocol_lc}.ovpn" ]; then
            config_file="${provider_dir}/${name_base}_${protocol_lc}.ovpn"
        elif [ -f "${provider_dir}/${name_base}" ]; then
            config_file="${provider_dir}/${name_base}"
        elif [ "${provider_lc}" = "nordvpn" ]; then
            # NordVPN: look in ovpn_udp/ or ovpn_tcp/ subdir
            nord_subdir="${provider_dir}/ovpn_${protocol_lc}"
            if [ -f "${nord_subdir}/${name_base}.ovpn" ]; then
                config_file="${nord_subdir}/${name_base}.ovpn"
            elif [ -f "${nord_subdir}/${name_base}" ]; then
                config_file="${nord_subdir}/${name_base}"
            fi
        else
            # Surfshark can optionally map friendly names (e.g. za_johannesburg -> actual file prefix)
            if [ "${provider_lc}" = "surfshark" ]; then
                map_file="${SURFSHARK_MAP_FILE:-${vpn_dir}/surfshark_map.json}"
                if [ -f "${map_file}" ]; then
                    mapped="$(jq -r --arg k "${name_base}" '.[$k] // empty' "${map_file}" 2>/dev/null || true)"
                    if [ -n "${mapped}" ]; then
                        debug_log "[Surfshark] mapped ${name_base} -> ${mapped}"
                        if [ -f "${provider_dir}/${mapped}.ovpn" ]; then
                            config_file="${provider_dir}/${mapped}.ovpn"
                        elif [ -f "${provider_dir}/${mapped}_${protocol_lc}.ovpn" ]; then
                            config_file="${provider_dir}/${mapped}_${protocol_lc}.ovpn"
                        fi
                    fi
                fi
            fi
        fi

        if [ -z "${config_file}" ]; then
            log "[OpenVPN] Config not found in provider dir: ${provider_dir}/${name_base}(.ovpn|_${protocol_lc}.ovpn)"
            exit 1
        fi
    fi
fi

if [ -z "${config_file}" ] || [ ! -f "${config_file}" ]; then
    log "[OpenVPN] No .ovpn config found"
    exit 1
fi

# Auth file
auth_file="${vpn_dir}/${provider_lc}-openvpn-credentials.txt"
if [ "${provider_lc}" = "custom" ]; then
    auth_file="${vpn_dir}/custom-openvpn-credentials.txt"
fi

if [ -n "${OPENVPN_USERNAME:-}" ] && [ -n "${OPENVPN_PASSWORD:-}" ]; then
    printf '%s\n%s\n' "${OPENVPN_USERNAME}" "${OPENVPN_PASSWORD}" > "${auth_file}"
    chmod 600 "${auth_file}"
fi

if grep -Eq '^auth-user-pass(\s|$)' "${config_file}"; then
    if [ ! -f "${auth_file}" ]; then
        log "[OpenVPN] auth-user-pass present but no credentials file (${auth_file})"
        exit 1
    fi
    # ensure it points at our auth file
    sed -i "s|^auth-user-pass.*|auth-user-pass ${auth_file}|" "${config_file}"
fi

# Clean config
/scripts/openvpn-config-clean.sh "${config_file}"

debug_log "[OpenVPN] selected config_file=${config_file}"

echo "OPENVPN_CONFIG_FILE=${config_file}"
if [ -f "${auth_file}" ]; then
    echo "OPENVPN_AUTH_FILE=${auth_file}"
fi
