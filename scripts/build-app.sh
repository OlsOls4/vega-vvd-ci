#!/usr/bin/env bash
# Scaffold (if needed) and build a Vega React Native app; prints the x86_64 vpkg path
# to $OUT/vpkg-path.txt. Env: APP_DIR, APP_NAME, PACKAGE_ID, TEMPLATE, OUT
set -euo pipefail
export PATH="$HOME/vega/bin:$PATH"
APP_DIR=${APP_DIR:-app}
APP_NAME=${APP_NAME:-HelloVega}
PACKAGE_ID=${PACKAGE_ID:-com.olsols4.hellovega}
TEMPLATE=${TEMPLATE:-helloWorld}
OUT=${OUT:-$PWD/artifacts}; mkdir -p "$OUT/logs"

if [[ ! -f "$APP_DIR/package.json" ]]; then
  echo "::group::vega project generate ($TEMPLATE)"
  vega project list-templates || true
  vega project generate --template "$TEMPLATE" --name "$APP_NAME" --packageId "$PACKAGE_ID" --outputDir "$APP_DIR"
  echo "::endgroup::"
fi
# Optional overlay: files in ./app-overlay replace template files (e.g. a custom App.tsx)
if [[ -d app-overlay ]]; then cp -rv app-overlay/. "$APP_DIR/"; fi

cd "$APP_DIR"
echo "::group::npm install"
npm install --no-audit --no-fund
echo "::endgroup::"
echo "::group::build"
if npm run | grep -q "build:release"; then npm run build:release; else npm run build:app; fi
echo "::endgroup::"
find build -name '*.vpkg' -exec ls -la {} \; | tee "$OUT/logs/vpkgs.txt"
VPKG=$(find "$PWD/build" -name '*x86_64*.vpkg' | grep -i release | head -1)
[[ -z "$VPKG" ]] && VPKG=$(find "$PWD/build" -name '*x86_64*.vpkg' | head -1)
[[ -z "$VPKG" ]] && { echo "no x86_64 vpkg built"; exit 1; }
echo "$VPKG" > "$OUT/vpkg-path.txt"
cp "$VPKG" "$OUT/"
grep -E '^\s*(id|package|component)' manifest.toml 2>/dev/null | head -20 || true
echo "built $VPKG"
