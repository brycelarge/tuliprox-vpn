#!/usr/bin/env bash
set -euo pipefail

exec /app/tuliprox -p /app/config --healthcheck
