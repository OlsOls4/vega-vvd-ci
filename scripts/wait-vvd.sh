#!/usr/bin/env bash
# Wait for a background start-vvd.sh (started by the action with boot: background).
set -uo pipefail
OUT=${OUT:-$PWD/artifacts}
T=${1:-600}
for _ in $(seq 1 $((T/5))); do [[ -f "$OUT/vvd-exit" ]] && break; sleep 5; done
cat "$OUT/logs/start-vvd.log" 2>/dev/null
[[ "$(cat "$OUT/vvd-exit" 2>/dev/null)" == "0" ]] || { echo "VVD failed to boot"; exit 1; }
