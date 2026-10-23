#!/usr/bin/env bash
# Kill ONLY the processes that belong to a `vega virtual-device start` run:
#   - the CLI process itself and every descendant of it,
#   - every process in the CLI's own session (start-vvd.sh launches the CLI
#     under `setsid`, so helpers it double-forks still share that session),
#   - the emulator process (and its descendants) if its PID is given,
#   - any process whose command line is `... virtual-device start ...`.
#
# It never matches by a generic process name such as `node`, so a concurrent
# `npm ci` / `npm run build` (npm runs as `node`) on the same runner survives.
# (v0 used `pkill -9 -x node`, which could SIGKILL the user's build.)
#
# Usage: vvd-kill.sh <cli-pid> [emulator-pid ...]
#   VVD_KILL_SIGNAL  signal to send (default KILL)
#   VVD_KILL_DRYRUN  1 = print the PIDs that would be killed, kill nothing
set -uo pipefail

SIG=${VVD_KILL_SIGNAL:-KILL}
[[ $# -ge 1 ]] || { echo "usage: vvd-kill.sh <cli-pid> [emulator-pid ...]" >&2; exit 2; }
for p in "$@"; do
  [[ "$p" =~ ^[0-9]+$ ]] || { echo "vvd-kill.sh: not a PID: $p" >&2; exit 2; }
done
cli_pid=$1

declare -A victims=()

add_tree() {  # add $1 and all its descendants
  local pid=$1 child
  [[ -d /proc/$pid ]] || return 0
  [[ -n "${victims[$pid]:-}" ]] && return 0
  victims[$pid]=1
  for child in $(pgrep -P "$pid" 2>/dev/null); do add_tree "$child"; done
}

for p in "$@"; do add_tree "$p"; done

# Session members, but only when the CLI leads its own session (never the
# runner's / caller's session).
if [[ -d /proc/$cli_pid ]]; then
  sid=$(ps -o sid= -p "$cli_pid" 2>/dev/null | tr -d ' ')
  if [[ -n "$sid" && "$sid" == "$cli_pid" ]]; then
    for p in $(pgrep -s "$sid" 2>/dev/null); do add_tree "$p"; done
  fi
fi

# Stray CLI instances (matched on their full command line, not on `node`).
for p in $(pgrep -f -- "virtual-device start" 2>/dev/null); do add_tree "$p"; done

# Never kill ourselves or our ancestors.
self=$$
while [[ -n "$self" && "$self" != "0" && "$self" != "1" ]]; do
  unset "victims[$self]"
  self=$(ps -o ppid= -p "$self" 2>/dev/null | tr -d ' ')
done

pids=("${!victims[@]}")
if [[ ${#pids[@]} -eq 0 ]]; then echo "vvd-kill: nothing to kill"; exit 0; fi
if [[ "${VVD_KILL_DRYRUN:-0}" == "1" ]]; then printf '%s\n' "${pids[@]}" | sort -n; exit 0; fi
echo "vvd-kill: SIG$SIG -> ${pids[*]}"
kill -s "$SIG" "${pids[@]}" 2>/dev/null || true
exit 0
