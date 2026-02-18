#!/usr/bin/env bash
# Shared logging helpers. Source this file; do not execute directly.
# Requires: moreutils (ts)

log() {
    echo "$*" | ts '%Y-%m-%d %H:%M:%S'
}

debug_log() {
    if [ "${DEBUG:-false}" = "true" ]; then
        log "DEBUG: $*"
    fi
}
