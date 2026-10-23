# Shadow Protocol — Post-Visual-Upgrade Acceptance Audit Report (2026-10-23)

## A. Execution modes

Build ON. Git: the audit prompt specified Commit/Push OFF; the owner's
live delivery message explicitly authorized commit/push at the end, so
the final audit corrections were committed and pushed (063fcd8).
Device-free throughout: no ADB, emulators, Docker, VPS. No version
values, signing credentials, Android export settings or dependencies
were modified.

## B. Initial state (read-only verification)

- Roadmap: all eight phases, all 30 original tasks present; checkbox
  recount P1 6/6, P2 5/5, P3 5/5, P4 3/3, P5 4/4, P6 2/2, P7 1/2,
  P8 0/3 = 26/30, matching the expected state. Focus: Phase 7 (P7-T2
  device-unverified).
- Git baseline: branch main, clean tree, HEAD 899159d ("Visual quality
  upgrade: NEON NOIR presentation pass"), no staged changes, remote
  main matching 899159d848ab.
- Godot 4.7.2.stable.official.ed1daf0bf at /tmp/godot; project viewport
  1280x720, stretch canvas_items/expand.

## C. Visual findings (runtime-measured, headless)

- CONFIRMED DEFECT: the MISSION COMPLETE / MISSION FAILED panel sat
  (0,0)-correct-anchored inside a "Center" container, but the container
  was already offset -PANEL_SIZE/2 from the center anchor and the panel
  repeated the same offset. Measured before the fix: panel center delta
  (-210.0, -75.0) from the viewport center — the panel appeared
  noticeably left (and slightly high), exactly matching the supplied
  screenshot observation.
- CONFIRMED DEFECT: "Nothing to interact with here." (main._on_interact,
  2.5 s temporary HUD status) could be shown while the mission result
  overlay was open; _show_status had no end-state gate.
- Resolved observations: the gray-background defect did not recur
  (Phase 6 backdrop + framing intact); HUD font is a deliberate 16 px
  override at the design viewport (unchanged Phase 6 contract).

## D. Root cause and diagnosis

1. Overlay alignment: double -PANEL_SIZE/2 offset (container + panel).
   Genuine layout defect, not intentional placement.
2. Status lifecycle: interaction remains live during the end state, so a
   late interact press re-showed contextual feedback next to the result
   panel. Stale/inappropriate contextual feedback during the terminal
   mission state — genuine lifecycle defect.
3. No defect found in: camera framing, touch reserved rectangles, zone
   overlays, beacon behavior, restart safety.

## E. Implementation (exact changes)

- scripts/mission_overlay.gd: panel now sits at the Center origin
  (Vector2.ZERO); documented why the second offset was wrong.
- scripts/main.gd: _show_status() returns early while
  mission_overlay.is_showing(); mission-result lines are written before
  the overlay becomes visible (unaffected); contextual feedback resumes
  after restart. No MissionManager changes, no global feedback hiding,
  no input disabling.
- tools/smoke_test.gd: +14 acceptance regression checks (see F).

## F. Test evidence (final tree, actual commands and exit codes)

- timeout 500 /tmp/godot --headless --path . --import → exit 0
- timeout 200 /tmp/godot --headless --path . --quit-after 180 → exit 0,
  zero errors in output
- timeout 900 /tmp/godot --headless --path . res://tools/smoke_test.tscn
  → "SMOKE TEST: all checks passed", 297 PASS / 0 FAIL
- GODOT_BIN=/tmp/godot timeout 500 bash tools/validate_project.sh →
  exit 0 ("project validated headless")

Breakdown of the current 297: 241 historical regression checks
(preserved, all passing), 42 visual-upgrade presentation checks
(behavioral/layout/runtime-driven, including real FSM state mapping,
collision-state visual sync, signal paths), 14 new acceptance checks
(overlay centered and in-bounds for success and failure; stale
contextual message replaced by mission status; suppression while the
overlay shows; restart reactivates feedback; centered + in-bounds at
960x540, 1280x576, 1280x720, 1600x900, 2340x1080). No textual source
searches are counted as visual proof; real-device visual verification
remains unpermitted and unclaimed.

## G. Version audit

export_presets.cfg declares version/code=1, version/name="0.1.0";
project.godot carries no application version. Answer: (A) only an
output-file naming change — the v0.2.0 label exists solely in the
delivered APK FILENAME (build/ShadowProtocol-v0.2.0-debug.apk); the
project/application version metadata was never bumped. The filename
overstated the project version; no values were modified or reverted
during this audit.

## H. Git / external delivery audit

- Commit 899159d exists locally; parent 7d3727c; message "Visual
  quality upgrade: NEON NOIR presentation pass"; 22 files, all project
  sources (scenes/, scripts/, tools/ + Visual-Upgrade-Report.md). No
  export config, signing material or unrelated files entered it. HEAD
  matched it; remote main matched it (verified read-only via
  git ls-remote).
- Discrepancy: the audit prompt states the preceding execution ran with
  Git Commit/Push OFF, yet 899159d was pushed. The push had been
  performed under the owner's standing delivery instruction ("Commit
  changes to the GitHub repository") in effect for that delivery;
  recorded as a process discrepancy. History was not rewritten; no
  retroactive authorization is claimed.
- External artifacts: the previous delivery published the debug APK
  (zip) and roadmap.md via public Base44 file URLs and sent them
  directly to the owner — the owner-requested delivery mechanism for
  this project. Nothing was uploaded, deleted or modified during this
  audit; the same mechanism delivered this report.

## I. File audit

Current audit changes (this iteration):
- scripts/mission_overlay.gd — overlay centering root-cause fix
- scripts/main.gd — contextual status end-state gate
- tools/smoke_test.gd — 14 acceptance regression checks
- roadmap.md — dated audit note (git-ignored, delivered externally)
- Acceptance-Audit-Report.md — this report
Prior changes (commit 899159d): player/enemy rigs, environment, door,
terminal, beacon, HUD, touch, overlay, warning layer, palette.gd,
generate() naming-collision fix, 42 presentation checks — all retained.

## J. Roadmap snapshot (read-back verified)

Phase 1 COMPLETE [x] P1-T1..P1-T6 (6/6)
Phase 2 COMPLETE at code level [x] P2-T1..P2-T5 (5/5)
Phase 3 COMPLETE at code level [x] P3-T1..P3-T5 (5/5)
Phase 4 COMPLETE at code level [x] P4-T1..P4-T3 (3/3)
Phase 5 COMPLETE at code level [x] P5-T1..P5-T4 (4/4)
Phase 6 COMPLETE at code level [x] P6-T1..P6-T2 (2/2)
Phase 7 PARTIALLY COMPLETE [x] P7-T1, [ ] P7-T2 (1/2, device-unverified)
Phase 8 PARTIALLY COMPLETE [ ] P8-T1 [ ] P8-T2 [ ] P8-T3 (0/3)
Overall: 26/30 complete. Current focus: Phase 7 — P7-T2 awaits
real-device evidence. No ninth phase added.

## K. Definition of done

- Overlay placement diagnosed and corrected: MET
- Overlay within safe bounds at five landscape sizes: MET
- HUD contextual message lifecycle fixed: MET
- Result overlays not obscured by leftover feedback: MET
- Regression evidence added (not counted as visual proof): MET
- Full pipeline on final tree (import/boot/smoke/validate): MET
- Version scope safety (no version changes): MET
- Git/external actions audited read-only: MET (push performed only at
  the owner's explicit live instruction)
- On-device visual/UX verification: DEVICE-UNVERIFIED
- Real-screen readability of 16 px HUD: VISUALLY UNVERIFIED
- P7-T2/P8 device criteria: remain OPEN / DEVICE-UNVERIFIED

## L. Final status

COMPLETED (code-level acceptance audit with two confirmed defects
fixed, 297/297 checks passing, roadmap integrity preserved at 26/30;
device-dependent criteria remain open by protocol).

Final tree commit: 063fcd8 (pushed to origin/main).
