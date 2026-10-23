# vega-vvd-ci

[![test](https://github.com/OlsOls4/vega-vvd-ci/actions/workflows/test.yml/badge.svg)](https://github.com/OlsOls4/vega-vvd-ci/actions/workflows/test.yml)
[![e2e: build, boot, run, record](https://github.com/OlsOls4/vega-vvd-ci/actions/workflows/vvd.yml/badge.svg)](https://github.com/OlsOls4/vega-vvd-ci/actions/workflows/vvd.yml)
[![release](https://img.shields.io/github/v/release/OlsOls4/vega-vvd-ci?sort=semver)](https://github.com/OlsOls4/vega-vvd-ci/releases)
[![licence: MIT](https://img.shields.io/badge/licence-MIT-blue.svg)](LICENSE)

**Build an Amazon Vega OS (Fire TV) React Native app and run it on the Vega Virtual Device (VVD) — headlessly, on a free GitHub-hosted runner — then capture screenshots, a 1080p screen recording and scripted D-pad (remote) input.**

No Docker. No GPU. No self-hosted runner. No Mac. One `ubuntu-24.04` job: **~7 min cold, ~4 min with the SDK cache warm** (install → build → boot → launch → demo → upload).

![D-pad focus moving across the Vega hello-world app, recorded on a GitHub Actions runner](docs/demo.gif)

*Recorded by this action's own screen recorder on a GitHub-hosted runner (2× speed): `press.sh right` walks focus across the tiles, `left` walks back.*

![Contact sheet: VVD home, app launched, focus moves, Home, launcher](docs/contact-sheet.png)

*Step screenshots from the same run: VVD home → app launched → D-pad right/left moves focus → Home → launcher.*

**Used by:** [OlsOls4/casttoyourtv-firetv](https://github.com/OlsOls4/casttoyourtv-firetv) ([`firetv.yml`](https://github.com/OlsOls4/casttoyourtv-firetv/blob/main/.github/workflows/firetv.yml)).

▶ **See it used for a real app:** [Cast to Your TV for Fire TV: Ask the TV](https://github.com/OlsOls4/casttoyourtv-firetv) was built, tested and filmed entirely with this action. Demo video (all footage recorded by vega-vvd-ci in GitHub Actions): https://youtu.be/jQjg995EgmY

## Why

The Vega SDK only installs on x86_64 Ubuntu (20.04/22.04/24.04) or macOS, and the VVD needs KVM. That rules out ARM Linux boxes, most cloud dev sandboxes and AI-agent sandboxes. GitHub's Linux runners have KVM, but there's no official "run the VVD in CI" recipe, and the obvious `vega virtual-device start --no-gui` boots a device whose screenshots come back **black**. This repo packages the working recipe as a composite action plus small scripts.

## What works (verified in CI, SDK 0.24.12112 / CLI 1.4.5 and 1.4.7)

| Capability | How | Status |
|---|---|---|
| Install SDK + VVD unattended | `NONINTERACTIVE=true bash get_vvm.sh` | ✅ ~3.5 min cold (6.2 GB); ~1 min from `actions/cache` (2.1 GB compressed) |
| Build a vpkg | `vega project generate` → `npm install` → `npm run build:release` | ✅ ~1 min |
| Boot VVD headless | Xvfb + Mesa llvmpipe + relaunch the emulator with `-gpu host` | ✅ ~60 s to home screen |
| Install + launch the app | `vega run-app <vpkg> <appId> -d VirtualDevice` | ✅ ~4 s |
| Screenshot (PNG, 1920×1080) | emulator console `screenrecord screenshot <dir>` | ✅ |
| Screen recording | emulator console `screenrecord start/stop` → WebM (VP9) → MP4 | ✅ full-motion 1080p, ≤180 s per clip |
| Remote / D-pad keys | `vega exec vda shell inputd-cli button_press KEY_RIGHT` | ✅ focus moves in the app and launcher |

## Use it in your own repo

```yaml
jobs:
  vvd:
    runs-on: ubuntu-24.04
    timeout-minutes: 60
    defaults: { run: { shell: "bash -eo pipefail {0}" } }
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: "22" }   # react-native-kepler 4.x wants Node >= 22.14

      - uses: OlsOls4/vega-vvd-ci@v1        # KVM + deps + Vega SDK + VVD boot (background)
        with:
          boot: background                  # background | foreground | none
          # sdk-version: 0.24.12112         # blank = latest

      - run: npm ci && npm run build:release   # your Vega app, built while the VVD boots
      - run: wait-vvd.sh 600
      - run: |
          vega run-app build/x86_64-release/myapp_x86_64.vpkg com.example.myapp.main -d VirtualDevice
          record.sh start "$OUT/demo.webm"
          sleep 10; screenshot.sh "$OUT/launched.png"
          press.sh right right select back
          record.sh stop
          ffmpeg -y -i "$OUT/demo.webm" -c:v libx264 -pix_fmt yuv420p "$OUT/demo.mp4"
      - uses: actions/upload-artifact@v4
        if: always()
        with: { name: vvd, path: artifacts/ }
```

The action puts `scripts/` on `PATH` and sets `OUT` (artifacts dir) and `DISPLAY`. A complete, copy-paste workflow is in [`examples/minimal.yml`](examples/minimal.yml).

Pin `@v1` (moves with compatible fixes) or `@v1.0.0` (exact). Avoid `@main`.

### Inputs

| Input | Default | Description |
|---|---|---|
| `sdk-version` | `""` (latest) | Vega SDK version, e.g. `0.24.12112`. Pin it for reproducible runs. |
| `boot` | `background` | `background`: boot while your next steps run (then call `wait-vvd.sh`). `foreground`: block until ready. `none`: install only. Anything else fails the step. |
| `boot-timeout` | `480` | Seconds to wait for a non-black home screen (positive integer). |
| `cache` | `true` | Cache `~/vega` with `actions/cache` (`true`/`false`). The key includes the SDK version; `latest` is bucketed by month so new SDKs get picked up. |
| `artifacts-dir` | `artifacts` | Where logs, screenshots and recordings go (relative to the workspace, or absolute). |

### Outputs

| Output | Description |
|---|---|
| `vega-version` | Output of `vega --version`. |
| `artifacts-dir` | Absolute artifacts path (same as `$OUT`). Handy for `upload-artifact`. |
| `display` | X display the VVD renders on (same as `$DISPLAY`). |

## What's new vs finloop/vega-virtual-device-action

[finloop/vega-virtual-device-action](https://github.com/finloop/vega-virtual-device-action) worked out the key trick (relaunch the emulator with `-gpu host` on Mesa llvmpipe + Xvfb so frames aren't black). All credit for that goes to them. This action packages the same idea differently:

| | vega-vvd-ci (this repo) | finloop/vega-virtual-device-action (per its README, Oct 2026) |
|---|---|---|
| Runtime | Directly on the runner. No Docker image to build. | Builds a Docker image (SDK + VVD + GL stack) on the runner, cached |
| Your app build | Same job; VVD boots **in the background while you build** (`boot: background` + `wait-vvd.sh`) | Device is booted, then your `script:` runs against it |
| Screen recording | ✅ `record.sh` → WebM → MP4, full-motion 1080p | Screenshot (`screenshot-path`) |
| Remote / D-pad input | ✅ `press.sh right select back …`, no extra deps (on-device `inputd-cli`) | Via Argent or Appium examples |
| SDK caching | `~/vega` via `actions/cache`, ~1 min restore, version-keyed | Docker build cache |
| Unit tests | ✅ shellcheck + actionlint + 56 pytest cases on every push, plus e2e | e2e smoke/navigation workflows |
| Versioned release | ✅ `@v1` / `@v1.0.0` | `@main` in its quick start |
| Tested on | ubuntu-24.04, Node 22, SDK 0.24.12112 / CLI 1.4.5 + 1.4.7 | ubuntu-22.04 quick start, Node 20 image |

Pick finloop's if you want a self-contained container image or Argent/Appium navigation; pick this one for a Docker-free, build-overlapped job with recording and D-pad helpers.

## Scripts

| Script | What it does |
|---|---|
| `start-vvd.sh` | Starts Xvfb + llvmpipe, lets `vega virtual-device start` create the instance, reads the emulator argv from `/proc`, kills it and relaunches the same binary with `-gpu host`; waits for a non-black frame and for `vda` to see `emulator-5554`. |
| `wait-vvd.sh [secs]` | Waits for a background boot to finish. |
| `screenshot.sh out.png` | PNG via the emulator console. |
| `record.sh start f.webm` / `record.sh stop` | Screen recording via the emulator console (`--time-limit`, max 180 s; set `REC_LIMIT`). |
| `press.sh up down left right select back home menu playpause …` | Remote keys via on-device `inputd-cli` (raw `KEY_*` codes also accepted; `PRESS_GAP` seconds between presses). |
| `vvd-console.py "cmd" …` | Send any emulator-console command. |
| `build-app.sh` | Scaffold (template) + build; copies `app-overlay/` over the template if present. |
| `run-demo.sh` | The demo used by this repo's workflow: launch, walk focus across the tiles, Home, relaunch; step screenshots + recording + slideshow MP4. |
| `stop-vvd.sh` | Stop the emulator (lets `~/vega` be cached). |
| `vvd-kill.sh <cli-pid> [emu-pid]` | Used by `start-vvd.sh`: kills only the CLI's own process tree/session and the emulator, never unrelated `node`/npm processes. |
| `validate-inputs.sh` | Used by `action.yml`: validates inputs, derives the outputs and cache key. |
| `contact-sheet.sh out.png shot.png …` | Tile step screenshots into one labelled PNG (needs ffmpeg). |

## Tests

Two workflows run on every push:

- **[`test.yml`](.github/workflows/test.yml)** (< 1 min, no emulator): `shellcheck`, `actionlint`, and a pytest suite in [`tests/`](tests) that runs the real scripts against a stub `vega` CLI and a fake emulator console:
  - `press.sh`: every key name → `KEY_*` code, raw `KEY_*` passthrough, unknown keys exit 2 and press nothing, failures propagate.
  - `wait-vvd.sh`: pass / fail / timeout / late finish.
  - `screenshot.sh`: PNG moved to the target path; error when the console produces none.
  - `vvd-console.py`: auth-token handshake, OK/KO parsing, bad token, no-auth console.
  - `vvd-kill.sh`: **regression test** for the v0 `pkill -9 -x node` bug: the CLI's tree and session die, an unrelated process named `node` survives, the caller's session is never swept.
  - `validate-inputs.sh`: bad `boot`/`boot-timeout`/`cache`/`sdk-version` fail with an annotation; outputs and cache key.
  - `contact-sheet.sh`: tiles screenshots into one PNG.
  - It also runs the action with `boot: backgorund` (a typo) and checks it fails fast.
- **[`vvd.yml`](.github/workflows/vvd.yml)** (~4–8 min, end to end): install, build, boot, launch, D-pad demo, screenshots + recording, with a `node` canary process that must survive the boot. Also runs **weekly** (Monday 06:17 UTC) against the latest SDK.

**[`release-assets.yml`](.github/workflows/release-assets.yml)** (manual) copies a verified e2e run's screenshots (as a contact sheet) and recordings onto a GitHub Release, so the evidence outlives the 14-day artifact retention.

Run the unit tests locally: `pip install pytest && python -m pytest tests` (Linux; no SDK needed).

## Measured timings (4 vCPU / 16 GB `ubuntu-24.04` runner)

| Run | SDK | Total job |
|---|---|---|
| Cold (no cache) | installed, 207–214 s | 425–478 s |
| Warm (`~/vega` restored from cache) | 0 s install | 227 s |

Boot to non-black home screen: 54–61 s. App install + launch: 3–4 s. Build (3 arches, release): ~60 s, overlapped with the boot.

## Run it here

Push to `main` (code changes), wait for the weekly run, or **Actions → "Vega VVD — build, boot, run, record" → Run workflow** (inputs: SDK version, template). Download the `vvd-artifacts` artifact:

```
artifacts/
  shots/NN-*.png          step screenshots (1920×1080)
  demo-console.webm/.mp4  full-motion recording of the whole demo
  demo-slideshow.mp4      2 s per step screenshot
  hellovega_x86_64.vpkg   the built app
  logs/                   emulator, CLI, build, help output, emulator argv
```

## Gotchas we hit (so you don't)

- **Black screenshots** with the CLI's default GPU mode (`swangle_indirect`). Only `-gpu host` (backed by Mesa llvmpipe on Xvfb) posts a colour buffer the console can read back. The CLI has no flag for it, hence the relaunch.
- **Don't** use QMP `screendump`. It reads the scanout and is always black. The on-device `gwsi-tool-screenshooter` isn't supported on VVD.
- `inputd-cli` worked over `vda shell` on a fresh 0.24 VVD **without** `vsm developer-mode enable`. `enable-devmode.sh` probes first and only enables it (VVD reboots) if needed.
- Key names: select = `KEY_ENTER`, home = `KEY_HOMEPAGE`.
- `ffmpeg -f x11grab` of the Xvfb display came out black even with the emulator window enabled. Use the console recorder.
- GitHub's default `bash -e` has no `pipefail`, so `script | tee log` hides failures. Set `shell: bash -eo pipefail {0}`.
- `actions/cache` of `~/vega` fails while the emulator is running (files change under tar). Stop the VVD first (`stop-vvd.sh`).
- Killing the phase-1 CLI with `pkill node` also kills your concurrent `npm` build (npm runs as `node`). v1.0.0 kills only the CLI's own session; see [CHANGELOG](CHANGELOG.md).

## Credits

The `-gpu host` + llvmpipe + relaunch technique was worked out by [finloop/vega-virtual-device-action](https://github.com/finloop/vega-virtual-device-action) (a Docker-based action). The `inputd-cli` key mapping comes from [software-mansion/argent](https://github.com/software-mansion/argent). This repo is a Docker-free take, runnable directly on the runner, and adds screen recording, D-pad helpers, background boot overlapped with the build, and unit tests (see [What's new](#whats-new-vs-finloopvega-virtual-device-action)).

Vega SDK © Amazon, under its own licence. It's downloaded at run time and not redistributed here.

## Licence

MIT
