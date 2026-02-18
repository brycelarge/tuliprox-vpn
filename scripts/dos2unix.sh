#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/scripts/logging.sh
source /scripts/logging.sh

if [ -z "${1:-}" ]; then
    log "[dos2unix] no parameter supplied for file to convert"
    exit 1
fi

if [ ! -f "${1}" ]; then
    log "[dos2unix] file '${1}' does not exist"
    exit 1
fi

# create temp files used during the conversion
TEMP_FILE="$(mktemp /tmp/dos2unixtemp.XXXXXXXXX)"
STDOUT_FILE="$(mktemp /tmp/dos2unixstdout.XXXXXXXXX)"

SOURCE_FILE="${1}"

# run conversion, creating new temp file
# Alpine installs dos2unix under /usr/bin/dos2unix
/usr/bin/dos2unix -v -n "${SOURCE_FILE}" "${TEMP_FILE}" > "${STDOUT_FILE}" 2>&1

# if the file required conversion then overwrite source file
if ! grep -q 'Converted 0' "${STDOUT_FILE}"; then
    debug_log "[dos2unix] line ending conversion required, moving '${TEMP_FILE}' to '${SOURCE_FILE}'"
    mv -f "${TEMP_FILE}" "${SOURCE_FILE}"
fi

rm -f "${TEMP_FILE}" "${STDOUT_FILE}"
