# Changelog

## Unreleased
- `amazon-sample.yml`: weekly consumer test that builds Amazon's
  `AmazonAppDev/vega-video-sample` and smoke-tests it on the VVD with `@v1.0.0`;
  drop-in copy in `examples/vega-video-sample/`. README: "Used by" section.
- `scripts/contact-sheet.sh` + `release-assets.yml`: attach a verified e2e run's
  contact sheet and recordings to a GitHub Release (assets don't expire).

## v1.0.0 (2026-10-23)

First versioned release. Use `OlsOls4/vega-vvd-ci@v1`.

### Fixed
- **Background boot could kill a concurrent npm build.** Phase 2 of `start-vvd.sh`
  ran `pkill -9 -x node` (and `pkill -9 virtualdevice`) to stop the Vega CLI before
  relaunching the emulator with `-gpu host`. npm runs as `node`, so with the
  documented `boot: background` + `npm ci && npm run build` pattern it could
  SIGKILL your build. The CLI now starts under `setsid`, and the new
  `scripts/vvd-kill.sh` kills only its process tree/session and the emulator.
  Covered by a unit regression test and a `node` canary in the e2e workflow.
  (A process listing from the verification run shows the CLI's own Node runs as
  `node_real`, so the old `pkill -x node` never even matched the CLI: it could
  only hit other `node` processes.)

### Added
- `test.yml`: shellcheck, actionlint and a pytest suite (stub `vega` CLI + fake
  emulator console) for `press.sh`, `wait-vvd.sh`, `screenshot.sh`,
  `vvd-console.py`, `vvd-kill.sh`, `validate-inputs.sh`; plus a check that the
  action rejects a typo'd `boot` input.
- Input validation (`boot`, `boot-timeout`, `cache`, `sdk-version`) with clear
  `::error` annotations.
- Outputs `artifacts-dir` and `display`.
- `examples/minimal.yml`, README inputs/outputs table, comparison with
  finloop/vega-virtual-device-action, demo GIF.
- Weekly scheduled end-to-end run.

### Changed
- Cache key includes the SDK version; `latest` is bucketed by month
  (`vega-sdk-Linux-latest-YYYY-MM-v3`) so new SDK releases are picked up.
- `press.sh` validates every key before pressing any, and exits non-zero if a
  press fails.
- `wait-vvd.sh` uses a real deadline and reports timeout vs boot failure.

Tested with Vega SDK 0.24.12112 / CLI 1.4.5 and 1.4.7 on `ubuntu-24.04`, Node 22.
