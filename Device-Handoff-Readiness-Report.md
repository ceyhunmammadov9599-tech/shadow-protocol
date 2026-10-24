# Shadow Protocol — Device-Free Release Readiness & Test Handoff Report (2026-10-24)

## A. Initial state

- Godot: 4.7.2.stable.official.ed1daf0bf (/tmp/godot; not on shell PATH)
- Toolchain: OpenJDK 17 at SDK jdk dir, build-tools 34.0.0/35.0.0,
  platform-tools, python3, bash
- Git: branch main, HEAD e24dc6a, clean working tree, empty staged index
- Roadmap on entry: 27/30 (P1 6/6, P2 5/5, P3 5/5, P4 3/3, P5 4/4,
  P6 2/2, P7 1/2, P8 1/3); P8-T2 complete, P7-T2/P8-T1/P8-T3 open
- Benchmark scenario IDs verified in tools/benchmark.gd: all nine
  (A_legacy_steady ... I_door_active) exist as documented
- setup_android.sh supports --preflight; no docs/ directory existed;
  no standalone APK verification script existed (gap)

## B. Backup recovery record (developer's Windows 11 evidence)

Recorded in roadmap.md under P8-T2 evidence: the developer downloaded
shadow-protocol-signing-backup-v1.spbk, confirmed the SPBK1 container
parameters (scrypt n=32768 r=8 p=1, AES-256-GCM), decrypted it with the
separately received recovery password (7975 bytes recovered), matched
ciphertext SHA-256 ff29bc5dbbd564ca288d773c1fa5dbe555baae8f14270bd8d85094ee71792638
(True), confirmed the expected member listing (keystore, both public
certificates, fingerprint file, credential record, restore instructions,
manifest), and removed the temporary decrypted file after inspection
(PowerShell evidence). Limits recorded honestly: this does not establish
a separate offsite backup, an independent Windows keytool verification
of the inner private-key entry, or any Android runtime behavior. No
secret values recorded. P8-T2 stays complete; count unchanged (27/30).

## C. Release artifact audit (fresh, this execution)

Artifact present: build/ShadowProtocol-v0.1.0-release.apk.

- ZIP integrity: python zipfile testzip -> None (153 entries), clean
- aapt2 dump badging: com.shadowprotocol.game, versionCode 1,
  versionName 0.1.0, native-code arm64-v8a
- apksigner verify: exit 0; v2 true, v3 true
- Certificate SHA-256: 74ec3b4ec475f65517f0676b30d801f9fc557a5bb733dcabd70a5f016c574a0b
  (matches the generated release key)
- Debug certificate 38be10fa...: absent (0 occurrences) - confirmed not used
- APK file SHA-256: fc40011c4182e2b0ce8e1359993f9a5ed763dd7d7929885303f5c5a056329a3b

## D. APK verification automation

- Existing tools inspected: build_android.sh verifies only during
  build; verify_release_keystore.sh covers keystores only. Gap found:
  no standalone reusable APK verifier.
- Created tools/verify_release_apk_host.sh: argument-count validation,
  missing/empty APK rejection, build-tools and java location via
  ANDROID_SDK_ROOT / SDK jdk / JAVA_HOME (no absolute hardcoded paths),
  ZIP integrity, package/version/ABI metadata checks, apksigner v2+v3
  checks, release fingerprint match, debug-certificate rejection,
  nonzero exit on failure, no secrets, no ADB/emulator.
- Verified: release APK -> 5 PASS / 0 FAIL, exit 0; debug APK ->
  rejected (exit 1, fingerprint mismatch); wrong usage/missing file ->
  exit 1. Fix history: added java PATH detection and a ${JAVA_HOME:-}
  guard under set -u (root cause: apksigner requires java; JAVA_HOME
  unset broke set -u).
- Host regression tests extended 21 -> 26 in tools/test_build_android_host.sh
  (syntax, path portability, release acceptance, debug rejection,
  argument validation). All passing.

## E. Fresh host test results (final tree)

- Import: timeout 500 godot --headless --import -> exit 0
- Boot: --quit-after 180 -> exit 0, no errors
- Smoke: res://tools/smoke_test.tscn -> exit 0, 297/297 PASS
- validate_project.sh -> exit 0 (includes Android host checks 26/26)
- setup_android.sh --preflight with java/godot on PATH -> exit 0,
  all six prerequisites present (without PATH: 2 detected missing -
  environment PATH detection, not a defect)

## F. Device readiness (preparation only; nothing claimed tested)

- P7-T2: 60 FPS test plan with the nine verified benchmark scenarios,
  mid-range device class definition, per-scenario metric list (avg FPS,
  median/95th/99th percentile frame times, sustained 10-minute thermal
  run, memory stability, input responsiveness), PASS/FAIL/NOT TESTED
  statuses. P7-T2 remains OPEN.
- P8-T1: install checklist separating host setup (verified), debug
  packaging, release packaging, signature validation, device install,
  first launch, permissions, relaunch, same-key upgrade; documents that
  a debug-keyed installation must be uninstalled before a release-key
  APK with the same package id (Android rejects cross-certificate
  updates). P8-T1 remains OPEN.
- P8-T3: gameplay acceptance matrix, 18 implemented mechanics (startup,
  orientation, joystick, buttons, multi-touch, collision, stealth,
  noise, AI, doors, terminals, extraction, success, failure, restart,
  HUD, audio, stress/stability) plus two honestly documented
  NOT-IMPLEMENTED items (main menu, pause/persistence - the game boots
  directly into a level). P8-T3 remains OPEN.
- Location: docs/ANDROID_DEVICE_ACCEPTANCE.md
- Remaining external prerequisites: a physical arm64 Android device
  and a developer-run device session per the handoff document.

## G. Roadmap snapshot

Eight phases, 30 unique task IDs, 27 complete / 3 open:
- Phase 1 6/6, Phase 2 5/5, Phase 3 5/5, Phase 4 3/3, Phase 5 4/4,
  Phase 6 2/2 (all COMPLETE at code level with historical evidence)
- Phase 7 1/2: P7-T1 complete; P7-T2 OPEN (device evidence pending)
- Phase 8 1/3: P8-T1 OPEN (device install pending), P8-T2 complete
  (debug + release signing verified; owner Windows 11 recovery
  confirmed), P8-T3 OPEN (device gameplay pending)
- Current focus: Phase 8 release delivery + remaining device tasks
- Counts recomputed from actual checkboxes: 27/30. No device-dependent
  task was marked complete.

## H. File audit (this execution)

- docs/ANDROID_DEVICE_ACCEPTANCE.md (new): device handoff plan for
  P7-T2/P8-T1/P8-T3 - in scope (sections 6-9)
- tools/verify_release_apk_host.sh (new): reusable host APK verifier -
  in scope (section 4)
- tools/test_build_android_host.sh (modified): +5 narrowly scoped
  verifier regression checks - in scope (section 4)
- roadmap.md (modified): P8-T2 evidence updated with the confirmed
  Windows 11 recovery record (section 2); dated handoff note appended
  (sections 6-10) - in scope
- No gameplay/source modifications; no pre-existing work touched.

## I. Git safety

- No credentials, keystores, passwords or decrypted material in any
  committed file (secret scan on staged content: clean).
- Final git state: changes limited to the four in-scope files above,
  staged and pushed at the owner's standing live instruction (this
  phase prompt specified Git OFF; the owner's delivery message again
  requested a final push - documentation-only push performed, flagged
  here honestly).
- No build artifacts uploaded to external services this iteration.
- No keystore regenerated; signing certificate unchanged; application
  id and version unchanged.

## J. Final status

- Host-side preparation: COMPLETED (verifier + handoff document +
  fresh full validation, all green)
- Release artifact validation: PASSED (fresh audit + automated
  verifier, 5 PASS / 0 FAIL)
- Device criteria: OPEN (P7-T2, P8-T1, P8-T3 - all require real-device
  evidence; nothing claimed tested on a device)
- Roadmap: 27/30
