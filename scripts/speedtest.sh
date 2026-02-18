#!/usr/bin/env bash
set -euo pipefail

# Prefer python speedtest-cli if installed, otherwise fall back to iperf3 client mode (requires you to supply a server).

if command -v speedtest-cli >/dev/null 2>&1; then
    exec speedtest-cli --simple
fi

if command -v speedtest >/dev/null 2>&1; then
    exec speedtest --accept-license --accept-gdpr
fi

if command -v iperf3 >/dev/null 2>&1; then
    if [ -z "${IPERF3_SERVER:-}" ]; then
        echo "IPERF3_SERVER not set" >&2
        exit 1
    fi
    exec iperf3 -c "${IPERF3_SERVER}" ${IPERF3_ARGS:-}
fi

echo "No speedtest tool installed (expected speedtest-cli, speedtest, or iperf3)" >&2
exit 1
