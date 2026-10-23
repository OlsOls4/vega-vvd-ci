#!/usr/bin/env bash
# Validate the action's inputs and derive outputs. Called by action.yml; testable
# on its own. Env in: IN_BOOT IN_TIMEOUT IN_CACHE IN_SDK IN_OUT (+ GITHUB_WORKSPACE,
# GITHUB_OUTPUT). Writes: out, display, sdk-key to $GITHUB_OUTPUT.
set -uo pipefail
err() { echo "::error title=vega-vvd-ci::$*"; exit 1; }

case "${IN_BOOT:-background}" in
  background|foreground|none) ;;
  *) err "input 'boot' must be background, foreground or none (got '${IN_BOOT}')";;
esac
[[ "${IN_TIMEOUT:-480}" =~ ^[1-9][0-9]*$ ]] || err "input 'boot-timeout' must be a positive integer of seconds (got '${IN_TIMEOUT}')"
case "${IN_CACHE:-true}" in
  true|false) ;;
  *) err "input 'cache' must be true or false (got '${IN_CACHE}')";;
esac
sdk=${IN_SDK:-}
[[ -z "$sdk" || "$sdk" =~ ^[0-9]+(\.[0-9]+)*$ ]] || err "input 'sdk-version' must look like 0.24.12112 or be blank (got '${sdk}')"

dir=${IN_OUT:-artifacts}
[[ "$dir" == /* ]] || dir="${GITHUB_WORKSPACE:-$PWD}/$dir"
display=${DISPLAY:-:99}
if [[ -n "$sdk" ]]; then key=$sdk; else key="latest-$(date -u +%Y-%m)"; fi

out_file=${GITHUB_OUTPUT:-/dev/stdout}
{
  echo "out=$dir"
  echo "display=$display"
  echo "sdk-key=$key"
} >> "$out_file"
echo "inputs ok: boot=${IN_BOOT:-background} timeout=${IN_TIMEOUT:-480}s cache=${IN_CACHE:-true} sdk=${sdk:-latest} out=$dir display=$display"
