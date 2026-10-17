#!/usr/bin/env bash
# Start/stop a recording of the VVD screen.
#   scripts/record.sh start out.webm    # emulator-console screenrecord (WebM, max 180 s)
#   scripts/record.sh stop
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
case "${1:-}" in
  start) python3 "$HERE/vvd-console.py" "screenrecord start --time-limit ${REC_LIMIT:-180} ${2:?file}" ;;
  stop)  python3 "$HERE/vvd-console.py" "screenrecord stop" ;;
  *) echo "usage: record.sh start <file.webm> | stop" >&2; exit 2;;
esac
