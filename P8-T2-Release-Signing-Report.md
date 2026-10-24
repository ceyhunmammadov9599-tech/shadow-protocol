# Shadow Protocol — P8-T2 Android Release Signing & Build Consistency Report (2026-10-24)

## A. Execution modes

Build Mode ON. The phase prompt specified Git Commit/Push OFF with the
developer handling Git separately; the owner's live delivery message for
this iteration explicitly instructed commit/push at the end, so the
final source changes were committed (ed5c32a) and pushed. Device-free
throughout: no ADB, emulator, device install, Docker, VPS or Supabase.
No keystore was created or modified; no credential was printed.

## B. Baseline

- Roadmap: eight phases, 30 unique task IDs, 26/30 complete, P8-T2 open.
- Git: branch main, HEAD 3de6a86, clean tree, empty index.
- Tools: Godot 4.7.2.stable.official.ed1daf0bf (/tmp/godot), Android SDK
  /root/android-sdk (build-tools 34.0.0/35.0.0, platform-tools), JDK 17
  (/root/android-sdk/jdk), apksigner, aapt2, keytool all present.
  (java not on the default PATH; supplied via /root/android-sdk/jdk/bin.)
- Export preset "Android": com.shadowprotocol.game, version/name 0.1.0,
  version/code 1, arm64-v8a only, gradle off, debug/release keystore
  entries all empty.

## C. Build and signing architecture

tools/build_android.sh drives a single Godot export. Debug: preset
defaults (debug keystore). Release: SHADOW_PROTOCOL_* environment
credentials, temporarily injected into export_presets.cfg, restored on
exit. tools/setup_android.sh / install_android.sh inspected: no
credential printing, no hidden ADB dependency in the build path
(install_android.sh is a separate, explicitly device-side script and
was not run). Signing readiness: NO release keystore exists anywhere
(preset keystore/release="", no SHADOW_PROTOCOL env vars, no .jks/
.keystore release files; only /root/.android/debug.keystore).

## D. Diagnosis and fixes (all in tools/build_android.sh)

1. Hard-coded artifact version ("v0.1.0" literal in OUT). Root cause of
   the naming-defect class; the earlier v0.2.0 mismatch itself came
   from a caller-supplied output path. Fix: version label extracted
   from export_presets.cfg version/name. Verified: host checks 2, 3, 4.
2. Release path used --export-debug even with release credentials: a
   debug-signed APK would have been named -release. Fix:
   --export-release when the release environment is configured.
   Verified: host check "release path uses --export-release".
3. Credentials reached sed through process arguments (password visible
   in argv). Fix: sed commands fed via stdin heredoc; fail-fast checks
   for keystore file existence and apksigner; in-script apksigner
   verification of release APKs. Verified: host checks 7, 8.
New file tools/test_build_android_host.sh (9 checks); wired into
tools/validate_project.sh as step 5/5 (exit-code propagation preserved).

## E. Debug APK (fresh, this run)

- Build: GODOT_BIN=/tmp/godot timeout 900 bash tools/build_android.sh
  → exit 0, build/ShadowProtocol-v0.1.0-debug.apk (28 MB). Non-fatal
  host-side note: the Godot export plugin printed "Could not create
  child process: adb" (its device probe; export completed; no ADB
  device operation was performed).
- Structure: python zipfile testzip → 162 entries, zero corrupt.
- Metadata: aapt2 dump badging → package com.shadowprotocol.game,
  versionCode 1, versionName 0.1.0, minSdk 24, arm64-v8a (consistent
  with the preset).
- Signature: apksigner verify --print-certs → exit 0; "Verifies";
  v2 scheme: true; v3 scheme: true; signer CN=Android Debug.

## F. Release APK

BLOCKED — NOT VERIFIED. Exact missing prerequisite: no authorized
release-signing configuration exists (no release keystore, no
SHADOW_PROTOCOL_KEYSTORE credentials). Per the protocol no keystore was
created and no debug-key fallback was used. The corrected release path
(--export-release + stdin credentials + apksigner gate) is in place and
awaits the developer's keystore; no placeholder build was attempted.

## G. Version consistency

Actual: versionName 0.1.0, versionCode 1 (preset and APK badging agree).
Filename logic now derives from the preset, so artifact names can no
longer drift from project metadata. The old v0.2.0 mismatch is closed:
its source was a caller-supplied output path, not project metadata; the
historical artifact build/ShadowProtocol-v0.2.0-debug.apk predates this
correction and is superseded by the fresh v0.1.0 build.

## H. Security

No credential values were printed, logged or committed. Credentials
never appear in process arguments (stdin heredoc). export_presets.cfg
restore is trap-guarded. Keystores untouched. The release flow requires
an existing keystore file and apksigner and verifies signatures before
reporting success. Remaining concern (recorded, unresolved): if the
host process is killed with SIGKILL mid-release-build, the temporarily
modified export_presets.cfg would remain on disk with the .bak backup
beside it (recoverable from .bak); unavoidable with Godot's preset-only
signing model.

## I. Regression testing

- Historical baseline: 297/297 (referenced, not rerun-then).
- Fresh final-tree run: --import exit 0; --quit-after 180 exit 0;
  smoke res://tools/smoke_test.tscn → "SMOKE TEST: all checks passed",
  297 PASS / 0 FAIL; tools/validate_project.sh exit 0 including the new
  step 5/5 host checks (9 PASS / 0 FAIL).
- Total host checks: 297 Godot smoke + 9 build-host = 306, all passing.
  Godot smoke checks do not prove Android runtime behavior; APK package
  verification and gameplay testing are separate evidence types.

## J. File audit

- tools/build_android.sh — modified: three fixes above (was: hard-coded
  version, --export-debug always, argv credentials).
- tools/test_build_android_host.sh — new: 9 host-only naming/signing
  checks (bash -n, version extraction, export_path agreement, no
  hard-coded versions, export modes, no ADB/install, stdin credentials).
- tools/validate_project.sh — modified: added guarded step 5/5 running
  the host checks; existing steps unchanged.
- roadmap.md — dated P8-T2 note added (delivered externally, not in the
  repository per the project convention). No gameplay, version,
  application-id or export-preset content changes.

## K. Roadmap (counts from checkboxes, read back)

Phase 1 6/6 (P1-T1..T6), Phase 2 5/5 (P2-T1..T5), Phase 3 5/5,
Phase 4 3/3, Phase 5 4/4, Phase 6 2/2, Phase 7 1/2 (P7-T1 done,
P7-T2 open), Phase 8 0/3 (P8-T1, P8-T2, P8-T3 open). Overall 26/30.
Current focus: Phase 8 — P8-T2 debug portion verified, release portion
blocked on a developer-provided keystore.

## L. Acceptance matrix (P8-T2)

- Debug APK exists: MET (fresh build, 28 MB)
- Debug structure valid: MET (162 entries, testzip clean)
- Debug signature verified: MET (apksigner v2+v3, exit 0)
- Release APK exists: NOT MET / BLOCKED (no keystore)
- Release structure valid: NOT MET / BLOCKED
- Release signature verified: NOT MET / BLOCKED
- Intended release config confirmed: BLOCKED (does not exist)
- Debug/release modes not confused: MET (script + host checks)
- APK metadata consistent with project config: MET
- No credentials exposed: MET
- No unauthorized keystore changes: MET (none performed)
- Build scripts propagate errors: MET (fail-fast + set -euo pipefail)
- Applicable host-side tests pass: MET (9/9)
- Godot final-tree validation passes: MET (pipeline exit 0)
- Roadmap evidence accurate: MET (P8-T2 left OPEN)

P8-T2 acceptance NOT met → task remains OPEN. P7-T2, P8-T1, P8-T3
remain open and DEVICE-UNVERIFIED.

## M. Git safety

Initial and final working tree: only the intended changes staged;
index otherwise empty; no reset/clean/stash of developer work. One
commit (ed5c32a) and one push to origin/main per the owner's live
instruction — the phase prompt's separate note that the developer
handles Git finalization is acknowledged, and the discrepancy is
recorded here. APK and roadmap remain outside the repository per the
project's standing convention. Historical commits/pushes were performed
by the developer per their clarification.

## N. Final status

PARTIALLY COMPLETED — P8-T2's device-free portion is done: three real
build-script defects fixed (release export mode, version-derived
naming, credential handling), debug APK rebuilt and fully verified
(structure, metadata, v2+v3 signature), 306 host checks passing.
Release signing itself is BLOCKED on a missing developer-provided
release keystore, so P8-T2 correctly remains OPEN at 26/30. Fresh
verification (this run) and historical evidence (297 baseline, prior
audits) are separated above; Android runtime behavior remains
DEVICE-UNVERIFIED.
