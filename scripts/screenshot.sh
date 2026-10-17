#!/usr/bin/env bash
# Capture the VVD screen to a PNG via the emulator console (host-side readback of
# the -gpu host colour buffer). Usage: scripts/screenshot.sh out.png
set -euo pipefail
OUT_PNG="${1:?usage: screenshot.sh <out.png>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"
python3 "$HERE/vvd-console.py" "screenrecord screenshot $tmp" >/dev/null
for _ in 1 2 3 4 5 6 7 8 9 10; do
  shot="$(ls -t "$tmp"/*.png 2>/dev/null | head -1 || true)"
  [[ -n "$shot" ]] && break; sleep 0.5
done
[[ -z "${shot:-}" ]] && { echo "no screenshot produced" >&2; rm -rf "$tmp"; exit 1; }
mkdir -p "$(dirname "$OUT_PNG")"; mv "$shot" "$OUT_PNG"; rm -rf "$tmp"
echo "saved $OUT_PNG ($(stat -c%s "$OUT_PNG") bytes)"
