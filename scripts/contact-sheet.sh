#!/usr/bin/env bash
# Tile step screenshots into one labelled contact-sheet PNG.
# Usage: contact-sheet.sh <out.png> <shot.png> [shot.png ...]
#   SHEET_COLS  columns (default 4)   SHEET_W  tile width in px (default 640)
# Labels come from the file names: 04-focus-get-started.png -> "4. focus get started".
set -euo pipefail
out=${1:?usage: contact-sheet.sh <out.png> <shot.png> [shot.png ...]}; shift
[[ $# -ge 1 ]] || { echo "contact-sheet.sh: no screenshots given" >&2; exit 2; }
cols=${SHEET_COLS:-4}; w=${SHEET_W:-640}
rows=$(( ($# + cols - 1) / cols ))
font=""
for f in /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf /usr/share/fonts/dejavu/DejaVuSans.ttf; do
  [[ -f "$f" ]] && { font="fontfile=$f:"; break; }
done
tmp=$(mktemp -d); i=0
for shot in "$@"; do
  i=$((i+1))
  label=$(basename "$shot" .png | sed -E 's/^[0-9]+-//; s/-/ /g')
  ffmpeg -v error -y -i "$shot" -vf "scale=${w}:-2,drawbox=y=ih-40:w=iw:h=40:color=black@0.6:t=fill,drawtext=${font}text='${i}. ${label}':x=12:y=h-31:fontsize=22:fontcolor=white" "$tmp/$(printf '%03d' "$i").png"
done
ffmpeg -v error -y -framerate 1 -i "$tmp/%03d.png" -vf "tile=${cols}x${rows}:padding=6:margin=6:color=0x111111" -frames:v 1 "$out"
rm -rf "$tmp"
echo "wrote $out ($i tiles, ${cols}x${rows})"
