#!/usr/bin/env bash
# Stop the VVD (so ~/vega can be cached cleanly).
export PATH="$HOME/vega/bin:$PATH"
python3 "$(dirname "$0")/vvd-console.py" "kill" >/dev/null 2>&1 || true
sleep 3
pkill -9 -x vega-virtual-de 2>/dev/null || true
vega exec vda kill-server >/dev/null 2>&1 || true
exit 0
