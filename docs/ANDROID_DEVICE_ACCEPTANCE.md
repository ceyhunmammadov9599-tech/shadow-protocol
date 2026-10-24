# Shadow Protocol — Android Device Acceptance Plan

Applies to the three remaining device-dependent roadmap tasks:
P7-T2 (stable 60 FPS on mid-range hardware), P8-T1 (end-to-end
installation), P8-T3 (on-device gameplay verification).

Everything in this document is prepared host-side. No device testing has
been performed. All device-dependent statuses are NOT TESTED.

## 1. Release artifact and signing identity

- Artifact: build/ShadowProtocol-v0.1.0-release.apk
- Package: com.shadowprotocol.game, versionName 0.1.0, versionCode 1
- ABI: arm64-v8a, minSdk 24
- Signature: APK Signature Scheme v2 + v3
- Release certificate SHA-256:
  74ec3b4ec475f65517f0676b30d801f9fc557a5bb733dcabd70a5f016c574a0b
- Host verification: tools/verify_release_apk_host.sh <apk>
  currently reports 5 PASS / 0 FAIL on the release APK (2026-10-24).
- Debug certificate (never valid for the release artifact):
  38be10fad45c9dce9a12929324ce5bb7c586ba523cbdd2107e0f7c22beee1676

## 2. Host-side checks already completed (device-free)

- Godot import / 180-frame headless boot: exit 0
- Smoke suite: 297/297 PASS
- Android build/signing host checks: 26/26 PASS
- Release APK verification: signature, fingerprint, metadata PASS
- Owner confirmed Windows 11 decryption of the encrypted signing backup
  with matching ciphertext SHA-256 (roadmap P8-T2 evidence)

## 3. P7-T2 — 60 FPS device test plan

Device class to record: mid-range Android (e.g. Snapdragon 6/7xx,
Helio G series, 6 GB RAM class), Android 12+, 60 Hz+ display.

Record: device model, chipset, OS version, resolution and refresh rate,
native renderer (Vulkan/OpenGL), room temperature and battery level.

Frame-rate method: Android GPU inspector or
`adb shell dumpsys gfxinfo com.shadowprotocol.game` on the device; do
not rely on host headless numbers; only on-device measurements count.

Scenarios (IDs verified in tools/benchmark.gd):
1. A_legacy_steady
2. B_layout_b_steady
3. C_layout_c_steady
4. D_seeded_7
5. E_stress_8_enemies
6. F_detection_active
7. G_movement_active
8. H_restart_cycle
9. I_door_active

Measure per scenario (run each at least 3 times):
- Average FPS over 60+ seconds
- Median frame time
- 95th and 99th percentile frame time
- Frame-time stability (sustained 10-minute representative gameplay for
  thermal assessment, then re-run one steady scenario)
- Thermal throttling observations
- Memory stability (any growth trend)
- Input responsiveness (subjective plus any dropped input)

Acceptance: sustained >= 55 FPS average with no sustained stutter
(99th percentile frame time < 50 ms) across scenarios on the recorded
mid-range device. Record results per scenario with status
PASS / FAIL / NOT TESTED.

## 4. P8-T1 — End-to-end installation checklist

Host setup (already verified host-side): tools/setup_android.sh
--preflight exit 0. Debug and release packaging verified host-side.

On-device steps (perform on the Windows 11 machine with a USB phone):
1. Copy build/ShadowProtocol-v0.1.0-release.apk to the device.
2. Verify the copy: tools/verify_release_apk_host.sh on the transferred
   file (optional, host-side) or compare SHA-256
   fc40011c4182e2b0ce8e1359993f9a5ed763dd7d7929885303f5c5a056329a3b.
3. Install (file manager or adb install -r path.apk).
4. First launch: app starts into the level without crash.
5. Permission behavior: no unexpected permission prompts (the game
   requests none).
6. Relaunch: app restarts cleanly.
7. Reinstall over itself: same-signature upgrade installs without
   uninstalling.

Upgrade note (record correctly): an existing installation signed with
the DEBUG certificate must be uninstalled before installing the
release-signed APK with the same package id — Android refuses to
update a package with a different signing certificate.

Status: NOT TESTED (device required).

## 5. P8-T3 — On-device gameplay acceptance matrix

Implemented mechanics only; no invented features. The game boots
straight into a level (no main menu, no pause, no save/persistence —
these are not implemented and must be recorded as NOT APPLICABLE,
not as failures).

| ID | Scenario | Expected | Evidence | Status |
|----|----------|----------|----------|--------|
| G1 | Startup | Level generates and renders < 10 s | Screen recording | NOT TESTED |
| G2 | Orientation | Landscape letterboxed correctly | Recording | NOT TESTED |
| G3 | Touch joystick | Movement follows drag, auto-centers | Recording | NOT TESTED |
| G4 | Crouch/sprint/interact buttons | Each triggers its mechanic | Recording | NOT TESTED |
| G5 | Multi-touch | Joystick + button simultaneously | Recording | NOT TESTED |
| G6 | Collision | No wall clipping during movement | Recording | NOT TESTED |
| G7 | Stealth visibility | Meter follows light/shadow | Recording | NOT TESTED |
| G8 | Noise | Sprint raises noise, enemies react | Recording | NOT TESTED |
| G9 | Enemy AI | patrol/suspicious/alert/search transitions | Recording | NOT TESTED |
| G10 | Doors | INTERACT opens/closes, LOS blocked when closed | Recording | NOT TESTED |
| G11 | Terminals | Interact completes objective | Recording | NOT TESTED |
| G12 | Extraction | Beacon + mission success overlay | Recording | NOT TESTED |
| G13 | Mission failure | Spotted twice -> failure overlay | Recording | NOT TESTED |
| G14 | Restart | R key or RESTART button regenerates level | Recording | NOT TESTED |
| G15 | HUD readability | HUD, meters, warnings legible on device | Photo | NOT TESTED |
| G16 | Audio | door/terminal/success/failure/warning events audible | Manual | NOT TESTED |
| G17 | Stress | 8-enemy scenario no crash for 5 min | Recording | NOT TESTED |
| G18 | Stability | No unrecoverable freezes in 20 min | Recording | NOT TESTED |
| G19 | Main menu | NOT IMPLEMENTED (boots directly) | n/a | N/A |
| G20 | Pause/resume, persistence | NOT IMPLEMENTED | n/a | N/A |

## 6. Evidence and issue reporting

For each executed check record: test ID, device plus OS, timestamp,
observed result, PASS/FAIL, evidence file (recording/log/photo), and any
notes. Report failures with reproduction steps and the affected
scenario. Keep evidence with the project records, not in the repo if it
contains personal device information.

## 7. Known limitations

- No device, emulator or ADB testing has been performed by the build
  environment.
- Host headless FPS numbers are NOT Android performance evidence.
- The build environment cannot capture thermal or battery behavior.
- Multi-touch and haptics can only be verified on real hardware.

## 8. Troubleshooting

- Install fails with signature error: uninstall the debug-keyed build
  first (see upgrade note in section 4).
- Install fails INSTALL_FAILED_NO_MATCHING_ABIS: device is not arm64;
  the release APK is arm64-v8a only.
- Black screen at launch: confirm Android 7.0+ (minSdk 24) and that the
  device supports Vulkan or GLES3.
