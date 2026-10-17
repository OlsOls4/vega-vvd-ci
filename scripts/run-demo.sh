#!/usr/bin/env bash
# With the VVD booted: launch the app, drive it with D-pad presses, capture
# screenshots at each step and a screen recording; produce MP4s in $OUT.
set -uo pipefail
export PATH="$HOME/vega/bin:$PATH"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT=${OUT:-$PWD/artifacts}; mkdir -p "$OUT/shots" "$OUT/logs"
PACKAGE_ID=${PACKAGE_ID:-com.olsols4.hellovega}
APP_ID=${APP_ID:-$PACKAGE_ID.main}
VPKG=${VPKG:-$(cat "$OUT/vpkg-path.txt")}
n=0
shot() { n=$((n+1)); local f; f=$(printf '%s/shots/%02d-%s.png' "$OUT" "$n" "$1"); "$HERE/screenshot.sh" "$f" || true; }

{ vega --help; vega device --help; vega virtual-device --help; } >"$OUT/logs/vega-help.txt" 2>&1 || true

echo "::group::developer mode (for inputd-cli)"
"$HERE/enable-devmode.sh" 2>&1 | tee "$OUT/logs/devmode.log"
echo "::endgroup::"
vega exec vda shell inputd-cli --help >"$OUT/logs/inputd-cli-help.txt" 2>&1 || true

shot home-before-launch

echo "::group::start recordings"
"$HERE/record.sh" start "$OUT/demo-console.webm" 2>&1 | tee "$OUT/logs/record-start.log"
if [[ "${VVD_WINDOW:-0}" == "1" ]]; then
  nohup ffmpeg -y -loglevel error -f x11grab -framerate 15 -video_size 1920x1080 -i "${DISPLAY:-:99}" \
     -c:v libx264 -preset ultrafast -pix_fmt yuv420p "$OUT/demo-xvfb.mp4" >"$OUT/logs/ffmpeg-x11grab.log" 2>&1 &
  echo $! > /tmp/ffmpeg.pid
fi
echo "::endgroup::"

echo "::group::run app"
t0=$SECONDS
if ! vega run-app "$VPKG" "$APP_ID" -d VirtualDevice 2>&1 | tee "$OUT/logs/run-app.log"; then
  echo "run-app failed; trying install-app + launch-app"
  vega device install-app --packagePath "$VPKG" -d VirtualDevice 2>&1 | tee -a "$OUT/logs/run-app.log"
  vega device launch-app --appName "$APP_ID" -d VirtualDevice 2>&1 | tee -a "$OUT/logs/run-app.log"
fi
vega device running-apps -d VirtualDevice 2>&1 | tee "$OUT/logs/running-apps.txt" || true
echo "launch took $((SECONDS-t0))s"
echo "::endgroup::"
sleep 12; shot app-launched
sleep 5;  shot app-settled

echo "::group::D-pad demo"
"$HERE/press.sh" down;  sleep 1; shot after-down
"$HERE/press.sh" right; sleep 1; shot after-right
"$HERE/press.sh" select; sleep 2; shot after-select
"$HERE/press.sh" home;  sleep 4; shot after-home
"$HERE/press.sh" right right; sleep 2; shot home-after-right-right
"$HERE/press.sh" down; sleep 2; shot home-after-down
echo "relaunch app"
vega device launch-app --appName "$APP_ID" -d VirtualDevice 2>&1 | tee -a "$OUT/logs/run-app.log" || true
sleep 8; shot app-relaunched
echo "::endgroup::"

echo "::group::stop recordings"
"$HERE/record.sh" stop 2>&1 | tee "$OUT/logs/record-stop.log"
[[ -f /tmp/ffmpeg.pid ]] && { kill -INT "$(cat /tmp/ffmpeg.pid)"; sleep 3; }
sleep 3
ls -la "$OUT"
if [[ -s "$OUT/demo-console.webm" ]]; then
  ffmpeg -y -loglevel error -i "$OUT/demo-console.webm" -c:v libx264 -pix_fmt yuv420p -movflags +faststart "$OUT/demo-console.mp4" || true
fi
# Always build a slideshow MP4 from the step screenshots (2 s per frame).
ffmpeg -y -loglevel error -framerate 0.5 -pattern_type glob -i "$OUT/shots/*.png" \
   -vf "scale=1280:-2,format=yuv420p" -r 25 -c:v libx264 "$OUT/demo-slideshow.mp4" || true
echo "::endgroup::"
ls -la "$OUT" "$OUT/shots"
