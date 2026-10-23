#!/usr/bin/env bash
# Wait for a background start-vvd.sh (started by the action with boot: background).
set -uo pipefail
OUT=${OUT:-$PWD/artifacts}
T=${1:-600}
POLL=${VVD_WAIT_POLL:-5}
[[ "$T" =~ ^[0-9]+$ ]] || { echo "usage: wait-vvd.sh [timeout-seconds]" >&2; exit 2; }
deadline=$((SECONDS + T))
until [[ -f "$OUT/vvd-exit" ]] || [[ $SECONDS -ge $deadline ]]; do sleep "$POLL"; done
cat "$OUT/logs/start-vvd.log" 2>/dev/null
[[ -f "$OUT/vvd-exit" ]] || { echo "VVD boot did not finish within ${T}s"; exit 1; }
[[ "$(cat "$OUT/vvd-exit")" == "0" ]] || { echo "VVD failed to boot (start-vvd.sh exit $(cat "$OUT/vvd-exit"))"; exit 1; }
echo "VVD ready"
