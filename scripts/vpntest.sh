#!/usr/bin/env bash
set -euo pipefail

# Run inside the container: docker exec tuliprox-vpn /scripts/vpntest.sh

PASS="\033[0;32m✔\033[0m"
FAIL="\033[0;31m✘\033[0m"

check() {
    local label="$1"
    local result="$2"
    local expected="${3:-}"
    if [ -n "${expected}" ] && echo "${result}" | grep -q "${expected}"; then
        printf "%b %s: %s\n" "${PASS}" "${label}" "${result}"
    elif [ -z "${expected}" ] && [ -n "${result}" ]; then
        printf "%b %s: %s\n" "${PASS}" "${label}" "${result}"
    else
        printf "%b %s: %s\n" "${FAIL}" "${label}" "${result:-no output}"
    fi
}

echo "── VPN Interface ────────────────────────────────────────"
if ip link show tun0 >/dev/null 2>&1; then
    tun_ip=$(ip addr show tun0 | awk '/inet / {print $2}' | head -1)
    printf "%b tun0 is up: %s\n" "${PASS}" "${tun_ip:-no IP}"
else
    printf "%b tun0 not found — VPN not connected\n" "${FAIL}"
fi

echo ""
echo "── Public IP ────────────────────────────────────────────"
pub_ip=$(curl -sf --max-time 10 https://api.ipify.org 2>/dev/null || echo "failed")
check "Public IP" "${pub_ip}"

ip_info=$(curl -sf --max-time 10 "https://ipinfo.io/${pub_ip}/json" 2>/dev/null || echo "{}")
vpn_country=$(echo "${ip_info}" | grep -o '"country": *"[^"]*"' | cut -d'"' -f4 || echo "unknown")
vpn_org=$(echo "${ip_info}" | grep -o '"org": *"[^"]*"' | cut -d'"' -f4 || echo "unknown")
check "Country" "${vpn_country}"
check "Org/ASN" "${vpn_org}"

echo ""
echo "── DNS ──────────────────────────────────────────────────"
dns_result=$(nslookup google.com 2>/dev/null | awk '/^Address: / {print $2; exit}' || echo "failed")
check "DNS resolution" "${dns_result}"

echo ""
echo "── Routing ──────────────────────────────────────────────"
default_route=$(ip route list match 0.0.0.0/0 | head -1)
check "Default route" "${default_route}"

echo ""
echo "── Speed Test ───────────────────────────────────────────"
echo "Running speedtest (this may take 30s)..."
/scripts/speedtest.sh || echo "Speedtest failed or not installed"
