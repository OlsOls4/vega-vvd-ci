#!/usr/bin/env bash
# Send Fire TV remote / D-pad presses to the VVD with the on-device inputd-cli
# (needs VVD developer mode: scripts/enable-devmode.sh).
# Usage: scripts/press.sh right right down select back home ...
# Names: up down left right select back home menu playpause rewind fastforward
#        or any raw Linux KEY_* code.
set -uo pipefail
GAP=${PRESS_GAP:-0.6}
[[ $# -ge 1 ]] || { echo "usage: press.sh <key> [key ...]" >&2; exit 2; }
keycode() {
  case "$1" in
    up) echo KEY_UP;; down) echo KEY_DOWN;; left) echo KEY_LEFT;; right) echo KEY_RIGHT;;
    select|ok|enter) echo KEY_ENTER;; back) echo KEY_BACK;; home) echo KEY_HOMEPAGE;;
    menu) echo KEY_MENU;; playpause) echo KEY_PLAYPAUSE;; rewind) echo KEY_REWIND;;
    fastforward|ff) echo KEY_FASTFORWARD;;
    KEY_*) [[ "$1" =~ ^KEY_[A-Z0-9_]+$ ]] && echo "$1" || return 1;;
    *) return 1;;
  esac
}
# Validate every key before pressing anything.
codes=()
for k in "$@"; do
  c=$(keycode "$k") || { echo "unknown key $k" >&2; exit 2; }
  codes+=("$c")
done
fail=0
for i in "${!codes[@]}"; do
  k=${*:i+1:1}; c=${codes[$i]}
  out=$(vega exec vda shell inputd-cli button_press "$c" 2>&1); rc=$?
  echo "press $k ($c) rc=$rc ${out:0:200}"
  [[ $rc -eq 0 ]] || fail=1
  sleep "$GAP"
done
exit "$fail"
