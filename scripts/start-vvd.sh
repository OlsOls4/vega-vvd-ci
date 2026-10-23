#!/usr/bin/env bash
# Boot the Vega Virtual Device (VVD) headlessly on a plain GitHub-hosted Ubuntu
# runner (no Docker, no GPU) so that screenshots/recordings are NOT black.
#
# Technique credit: finloop/vega-virtual-device-action (docs/vvd-docker-screenshot-fix.md).
#   1. Xvfb display + Mesa llvmpipe (software GL on the CPU).
#   2. Let `vega virtual-device start` create the instance, read the emulator argv
#      from /proc, kill it, and relaunch the same binary with `-gpu host`
#      (the CLI picks swangle_indirect, which renders but captures black).
#   3. Make sure ::1 resolves (QEMU binds a GNSS chardev on ::1).
#
# Env:
#   VVD_BOOT_TIMEOUT  seconds to wait for a non-black home screen (default 420)
#   VVD_DISPLAY       X display (default :99)
#   VVD_WINDOW        1 = keep the emulator window on Xvfb (lets ffmpeg x11grab it)
#   OUT               artifacts dir (default $PWD/artifacts)
set -uo pipefail

TIMEOUT=${VVD_BOOT_TIMEOUT:-420}
export DISPLAY=${VVD_DISPLAY:-:99}
OUT=${OUT:-$PWD/artifacts}
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$OUT/logs"
export PATH="$HOME/vega/bin:$PATH"
export KEPLER_CSAT_DISABLED=true

log() { echo "[start-vvd $(date +%H:%M:%S)] $*"; }

# --- ::1 loopback ------------------------------------------------------------
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0  >/dev/null 2>&1 || true
sudo sysctl -w net.ipv6.conf.lo.disable_ipv6=0   >/dev/null 2>&1 || true
getent hosts ::1 >/dev/null || echo "::1 localhost" | sudo tee -a /etc/hosts >/dev/null

# --- Xvfb + software GL --------------------------------------------------------
export LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe \
       __GLX_VENDOR_LIBRARY_NAME=mesa MESA_LOADER_DRIVER_OVERRIDE=llvmpipe
if ! xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
  log "starting Xvfb on $DISPLAY"
  nohup Xvfb "$DISPLAY" -screen 0 1920x1080x24 -nolisten tcp >"$OUT/logs/xvfb.log" 2>&1 &
  for _ in $(seq 1 30); do xdpyinfo -display "$DISPLAY" >/dev/null 2>&1 && break; sleep 0.5; done
fi
glxinfo -B 2>/dev/null | grep -E "renderer|version string" || true

# --- phase 1: let the CLI create the instance --------------------------------
vega virtual-device start --help >"$OUT/logs/vvd-start-help.txt" 2>&1 || true
START_ARGS=(--gui=false --gl-accel=true)
grep -q -- "--no-gui" "$OUT/logs/vvd-start-help.txt" && ! grep -q -- "--gui" "$OUT/logs/vvd-start-help.txt" && START_ARGS=(--no-gui)
log "phase 1: vega virtual-device start ${START_ARGS[*]}"
# setsid: the CLI leads its own session, so phase 2 can kill exactly its process
# group/session instead of every `node` on the runner.
setsid vega virtual-device start "${START_ARGS[@]}" --timeout "$TIMEOUT" >"$OUT/logs/vvd-cli-phase1.log" 2>&1 < /dev/null &
cli_pid=$!
log "phase 1 CLI pid $cli_pid"

emu_pid=""
for _ in $(seq 1 300); do
  emu_pid=$(pgrep -x vega-virtual-de | head -1 || true)
  [[ -n "$emu_pid" ]] && break
  sleep 1
done
if [[ -z "$emu_pid" ]]; then
  log "ERROR: emulator process never appeared"; cat "$OUT/logs/vvd-cli-phase1.log"; exit 1
fi
sleep 2
mapfile -d '' -t ARGV < "/proc/${emu_pid}/cmdline"
EMU_BIN="${ARGV[0]}"
EMU_ARGS=("${ARGV[@]:1}")
printf '%q ' "${ARGV[@]}" >"$OUT/logs/emulator-argv-phase1.txt"; echo >>"$OUT/logs/emulator-argv-phase1.txt"
log "emulator binary: $EMU_BIN"
AGENT_DIR="$(cd "$(dirname "$EMU_BIN")/../.." && pwd)"

# Optionally drop -no-window so the emulator draws a window on Xvfb.
if [[ "${VVD_WINDOW:-0}" == "1" ]]; then
  NEW=(); for a in "${EMU_ARGS[@]}"; do [[ "$a" == "-no-window" ]] && continue; NEW+=("$a"); done
  EMU_ARGS=("${NEW[@]}")
fi

# --- phase 2: relaunch with -gpu host -----------------------------------------
log "phase 2: relaunch with -gpu host (llvmpipe)"
ps -eo pid,ppid,sid,pgid,comm,args >"$OUT/logs/ps-before-phase2.txt" 2>&1 || true
# Kill only the CLI's own tree/session + the emulator it started (never `pkill node`:
# that would also kill a concurrent `npm ci` / `npm run build`).
"$HERE/vvd-kill.sh" "$cli_pid" "$emu_pid"
for _ in $(seq 1 20); do kill -0 "$emu_pid" 2>/dev/null || break; sleep 0.5; done
pkill -9 -x vega-virtual-de 2>/dev/null || true   # emulator binary only (15-char comm)
wait "$cli_pid" 2>/dev/null || true
sleep 2
ps -eo pid,ppid,sid,pgid,comm,args >"$OUT/logs/ps-after-phase2-kill.txt" 2>&1 || true
rm -f /tmp/qmp-socket-*.sock
export LD_LIBRARY_PATH="${AGENT_DIR}/lib64/libstdc++:${AGENT_DIR}/lib64/gles_swiftshader:${AGENT_DIR}/lib64:${LD_LIBRARY_PATH:-}"
setsid "$EMU_BIN" -gpu host "${EMU_ARGS[@]}" >"$OUT/logs/emulator.log" 2>&1 < /dev/null &
disown || true
printf '%q ' "$EMU_BIN" -gpu host "${EMU_ARGS[@]}" >"$OUT/logs/emulator-argv-phase2.txt"

# --- wait for console, then for a non-black frame --------------------------------
deadline=$((SECONDS + TIMEOUT))
until ss -ltn 2>/dev/null | grep -q ':5554 '; do
  pgrep -x vega-virtual-de >/dev/null || { log "ERROR: emulator exited"; tail -50 "$OUT/logs/emulator.log"; exit 1; }
  [[ $SECONDS -ge $deadline ]] && { log "ERROR: console never opened"; tail -50 "$OUT/logs/emulator.log"; exit 1; }
  sleep 2
done
log "console up on :5554 after ${SECONDS}s total"

i=0
while true; do
  i=$((i+1))
  if "$HERE/screenshot.sh" "$OUT/boot-progress.png" >/dev/null 2>&1; then
    sz=$(stat -c%s "$OUT/boot-progress.png")
    if [[ "$sz" -gt 80000 ]]; then log "non-black frame ($sz bytes) after ${SECONDS}s"; break; fi
  fi
  pgrep -x vega-virtual-de >/dev/null || { log "ERROR: emulator exited during boot"; tail -50 "$OUT/logs/emulator.log"; exit 1; }
  [[ $SECONDS -ge $deadline ]] && { log "ERROR: no non-black frame within ${TIMEOUT}s"; exit 1; }
  sleep 5
done

# --- wait for the device to be reachable over vda --------------------------------
for _ in $(seq 1 60); do
  if vega exec vda devices 2>/dev/null | grep -qE 'emulator-[0-9]+\s+device'; then break; fi
  sleep 3
done
vega exec vda devices || true
vega device list || true
log "VVD ready (${SECONDS}s)"
