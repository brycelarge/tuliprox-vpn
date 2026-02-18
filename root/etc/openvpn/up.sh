#!/usr/bin/env bash
# Called by OpenVPN after the tunnel is up (--up hook).
# Re-adds LOCAL_NETWORK routes via the physical interface so LAN/GUI stays reachable.

source /scripts/logging.sh

# OpenVPN --up scripts don't inherit container env — read from s6 environment
if [ -z "${LOCAL_NETWORK:-}" ] && [ -f /run/s6/container_environment/LOCAL_NETWORK ]; then
    LOCAL_NETWORK="$(cat /run/s6/container_environment/LOCAL_NETWORK)"
fi

if [ -z "${LOCAL_NETWORK:-}" ]; then
    exit 0
fi

# Find the physical gateway, explicitly excluding tun0
gw="$(ip route list match 0.0.0.0/0 | awk '$5 != "tun0" {print $3; exit}')"
intf="$(ip route list match 0.0.0.0/0 | awk '$5 != "tun0" {print $5; exit}')"

if [ -z "${gw}" ] || [ -z "${intf}" ]; then
    log "[OpenVPN] up.sh: could not determine physical gateway, skipping routes"
    exit 0
fi

# Always re-add the Docker bridge subnet so port-mapped traffic can return via eth0
docker_net="$(ip route show dev "${intf}" proto kernel | awk '{print $1; exit}')"
if [ -n "${docker_net}" ]; then
    log "[OpenVPN] up.sh: ensuring docker bridge route ${docker_net} dev ${intf}"
    ip route replace "${docker_net}" dev "${intf}" proto kernel 2>/dev/null || true
fi

# Add user-defined LOCAL_NETWORK routes
for net in ${LOCAL_NETWORK//,/ }; do
    log "[OpenVPN] up.sh: adding route ${net} via ${gw} dev ${intf}"
    ip route replace "${net}" via "${gw}" dev "${intf}" 2>/dev/null || true
done
