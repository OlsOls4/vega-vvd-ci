#!/usr/bin/env bash
# Send Fire TV remote / D-pad presses to the VVD with the on-device inputd-cli
# (needs VVD developer mode: scripts/enable-devmode.sh).
# Usage: scripts/press.sh right right down select back home ...
# Names: up down left right select back home menu playpause rewind fastforward
#        or any raw Linux KEY_* code.
set -uo pipefail
GAP=${PRESS_GAP:-0.6}
for k in "$@"; do
  case "$k" in
    up) c=KEY_UP;; down) c=KEY_DOWN;; left) c=KEY_LEFT;; right) c=KEY_RIGHT;;
    select|ok|enter) c=KEY_ENTER;; back) c=KEY_BACK;; home) c=KEY_HOMEPAGE;;
    menu) c=KEY_MENU;; playpause) c=KEY_PLAYPAUSE;; rewind) c=KEY_REWIND;;
    fastforward|ff) c=KEY_FASTFORWARD;; KEY_*) c=$k;;
    *) echo "unknown key $k" >&2; exit 2;;
  esac
  out=$(vega exec vda shell inputd-cli button_press "$c" 2>&1); rc=$?
  echo "press $k ($c) rc=$rc ${out:0:200}"
  sleep "$GAP"
done
