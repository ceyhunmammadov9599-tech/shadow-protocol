# Shadow Protocol — Phase 8 Report: Android Packaging (Device-Free Preparation)

Date: 2026-10-23 · Godot 4.7.2.stable · Commit baseline: 130ac14 → this phase's commit
Status: Phase 8 PARTIALLY COMPLETE — host portion of P8-T1 and debug signing of P8-T2 verified; install step, release signing and on-device criteria OPEN. Roadmap stays at 26/30 tasks (P8-T1/P8-T2 now host-level partials).

## What was done

### 1. Script audit (all three tools reviewed, no device interaction)
- `setup_android.sh`: diagnostics-only, no auto-install, no adb, no sudo — confirmed. Gap found: no build-tools detection and no machine-usable exit code.
- `build_android.sh`: preset/export path checks confirmed against `export_presets.cfg` (preset `Android`, output `build/ShadowProtocol-v0.1.0-debug.apk`); secrets only via environment variables (release) — confirmed. Gaps found: wrong export flag (see finding F1), no SDK presence check, unbounded execution.
- `install_android.sh`: adb-only, requires a device — confirmed; never executed.

### 2. Concrete findings and corrections (all evidence-backed)
1. **F1 — wrong export flag (root cause of all previous build timeouts):** `build_android.sh` used `--export-project`, which is Godot 3 syntax; Godot 4 has `--export-release` / `--export-debug` / `--export-pack`. With the unknown flag, Godot silently booted the game instead of exporting; the game loop never quits, so every run hung until the 900 s timeout and reported "Export failed." Verified empirically: the same hang reproduced on a minimal one-scene project, proving it was script-level, not project-level. Fixed to `--export-debug` (debug template + debug APK intent).
2. **F2:** no Android SDK presence check → added explicit check with actionable message (`ANDROID_SDK_ROOT`, build-tools aapt2).
3. **F3:** unbounded export → wrapped in `timeout 900`.
4. **F4:** `setup_android.sh` gained step 6 (build-tools aapt2+apksigner detection), a truthful `--preflight` mode (exit 0 only when every prerequisite is present; installs nothing), and a step-4 refinement accepting directly-provisioned SDK layouts (sdkmanager is not the only valid layout).
5. **F5:** `install_android.sh` header clarified: requires a physical device; must never run in device-free pipelines.

### 3. Host environment provisioned (user-level only, official sources)
- Export templates 4.7.2.stable (Godot release .tpz, version-verified by the successful export)
- Android build-tools 34.0.0 (aapt2 2.19, apksigner, zipalign), platform android-34, platform-tools (Google repository zips)
- Temurin JRE 17.0.21 (java_sdk_path configured)
- Pre-existing `~/.android/debug.keystore` used for debug signing
- Godot editor settings corrected: android_sdk_path → actual SDK root; debug keystore path → existing file; java_sdk_path → JDK 17
- No system-wide packages installed; no sudo; `install_android.sh` never invoked

### 4. Device-free APK export — VERIFIED
- Preflight: all six prerequisites present, exit 0.
- `tools/build_android.sh` executed host-side → `[ DONE ] export`, `Signed`, `Verifying APK` green.
- Output: `build/ShadowProtocol-v0.1.0-debug.apk`, 28 MB, 152 entries.
- Architecture: arm64-v8a only (no armeabi-v7a/x86/x86_64 entries) per preset.
- Contents: AndroidManifest.xml present; compiled `.gdc` scripts and exported scenes embedded under `assets/`.
- Signature (apksigner verify --verbose): **Verifies**; v2 scheme true, v3 scheme true; 1 signer, **CN=Android Debug**; SHA-256 `38be10fad45c9dce9a12929324ce5bb7c586ba523cbdd2107e0f7c22beee1676`.

### 5. Full host validation pipeline — GREEN (on the final tree)
- `--import`: 0 errors
- Headless boot 180 frames: OK
- Smoke suite: all PASS (includes Phase 7 fixtures: freed-player AI safety, light registration, 5-cycle no-leak 292→292, 8-enemy stress, counter inertness, teardown)
- `tools/validate_project.sh`: OK
- `bash -n` on all four scripts: OK

## Open items (actionable requirements)
- **P8-T1 (install step):** requires a physical Android device with USB debugging; run `tools/install_android.sh`.
- **P8-T2 (release signing):** requires a release keystore; set `SHADOW_PROTOCOL_KEYSTORE`, `SHADOW_PROTOCOL_KEYSTORE_USER`, `SHADOW_PROTOCOL_KEYSTORE_PASSWORD` and build — the workflow is implemented and documented, secrets never enter the repo.
- **P8-T3 (on-device gameplay):** requires the same device; verify rendering, touch, performance (also gates P7-T2's 60 FPS criterion).
- Keystore/secret note: release credentials are only ever read from environment variables; `*.keystore`, `keystore.properties` and `export_presets.local.cfg` are git-ignored.

## Deliverables
- Signed debug APK (28 MB): delivered separately, kept out of the repo (build/ is git-ignored).
- Updated `roadmap.md`: delivered separately (git-ignored by design).
- Repo changes committed and pushed: `tools/setup_android.sh`, `tools/build_android.sh`, `tools/install_android.sh`, `README.md`.
