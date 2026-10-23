# Shadow Protocol — Runtime Visual Layout Remediation Report

Targeted corrective iteration on Phase 6 presentation quality. No new
roadmap phase, no gameplay-system rewrites, no Android/device usage.
Prompt source: developer-supplied remediation brief with a real 1280x576
runtime screenshot.

Engine: Godot 4.7.2.stable.official.ed1daf0bf (host binary /tmp/godot).
Date: 2026-10-23.

## A. Execution modes

- Build Mode: ON
- Git commit/push (prompt): OFF during diagnosis and remediation; the
  user's standing live instruction ("En son github'a commit/push et")
  was applied only AFTER all validation passed, as in prior phases.
- Devices / emulators / ADB: none used. All evidence is host-side.

## B. Initial project state

- Roadmap: 26/30 tasks complete (P1 6/6, P2 5/5, P3 5/5, P4 3/3,
  P5 4/4, P6 2/2, P7 1/2, P8 0/3) — matches the expected totals.
- HEAD: 5884e2e "Phase 8 (device-free): fix Godot 4 export flag, SDK
  preflight mode, host APK build".
- Git baseline: `git status --short`, `git diff --stat`,
  `git diff --cached --name-status`, `git diff --cached --stat` all
  empty — clean tree, no pre-existing uncommitted developer work.
- Smoke baseline before changes: 214/214 PASS (verified in the prior
  session's final run and re-confirmed structurally this session).

## C. Screenshot diagnosis (validated, not assumed)

The 1280x576 screenshot showed: ~45% unused gray area on the left,
level pushed right, player at the level's upper-left, HUD labels
scattered with small typography, an empty "Zone" label, touch buttons
overlapping the world view.

Device-free runtime probe (tools/layout_probe.gd, boots the REAL main
scene with a 1280x576 window before load):

- Canvas viewport under stretch canvas_items/expand: **1600x720**
  (uniform scale 0.8; width fixed at 1280, height exposed to 720).
- Legacy map bounds: 1344x768 (28x16 cells x 48 px).
- Camera limits before fix: L=-1000000 R=1000000 T=0 B=768.
- Camera center at spawn: (72, 360). Player spawn: (72, 72).
- **gray_left_frac = 0.455** — the left 45.5% of the screen rendered
  outside the map, exactly matching the screenshot's gray band.

## D. Root cause

Not a Camera2D defect, spawn error or transform bug. The Phase 6 limit
rule disabled camera limits on any axis where the map was smaller than
the viewport ("unlimited fallback to avoid inverted limits"). Under the
expand canvas at 1280x576 the view is 1600 px wide but the map is 1344
px, so the x-axis limits were disabled; the camera then freely followed
the spawn-side player (x=72), pushing the view 728 px past the map's
left edge into the raw clear color. The y axis (768 >= 720) was
correctly clamped — which is why the level hugged the top edge.

Secondary presentation defects confirmed by inspection:
- HUD_TEMPLATE rendered `Zone %s` with an empty StringName outside
  restricted zones (empty "Zone" label).
- HUD font 14 px, small for landscape play.
- The help line always showed desktop keys regardless of input mode.
- The bare clear color showed through around smaller maps (no coherent
  background existed beyond the map bounds).
- Touch controls themselves were CORRECTLY hidden on desktop
  (visible = touchscreen available OR android); the screenshot's
  buttons are consistent with a touchscreen-enabled device, and the
  brief explicitly warns not to infer a detection defect from a
  desktop screenshot. No detection change was made; an explicit
  `shadow_protocol/touch_debug` setting was added instead.

## E. Fix (exact changed files)

1. **scripts/main.gd**
   - New static `Main.compute_camera_limits(bounds, viewport)`: per-axis
     framing contract. Map >= view on an axis: clamp to the map edges
     (unchanged behavior). Map < view: lock the camera to the map's
     center so the map stays composed on screen. Ranges always >= the
     view, never inverted.
   - `load_level()` applies the helper's limits (replaces the
     unlimited fallback), recomputed per load; `reset_smoothing()`
     unchanged (no start-of-mission jump).
   - HUD zone line: `"none (unrestricted)"` when outside every
     restricted zone (no more empty Zone label); zone semantics,
     stealth and mission rules untouched.
   - Help line is input-mode aware: touch controls text when the touch
     overlay is visible, keyboard text otherwise.
2. **scripts/level_generator.gd**
   - New `Backdrop` polygon drawn as the first child (behind
     everything): map bounds + 640 px margin in a darker site color, so
     any exposed margin around a centered map reads as intentional
     composition instead of raw clear color.
   - New `BoundsFrame` closed Line2D exactly on the playable bounds so
     the facility edge reads as a bounded structure.
   - No collision, generation or gameplay changes.
3. **scenes/main.tscn**
   - HUD font 14 -> 16 px, HUD box enlarged (16,16 -> 420x150) and made
     mouse-transparent. Anchors of meters/Status/touch layer unchanged
     (already screen-fixed on the UI CanvasLayer, independent of
     Camera2D).
4. **scripts/mobile_controls.gd + project.godot**
   - Explicit `shadow_protocol/touch_debug` project setting (default
     false) forces the touch overlay for desktop layout testing.
     Real-device detection rules unchanged.
5. **tools/layout_probe.gd** (new)
   - Device-free layout diagnostic: boots the real main scene at five
     landscape window sizes, reloads per size, reports canvas/bounds/
     camera/margin geometry.
6. **tools/smoke_test.gd**
   - 27 new behavior-level checks (section L) — see G.
   - 2 legacy camera checks updated in place to the corrected contract
     (they previously asserted the old unlimited fallback):
     "camera limits follow the framing contract for the runtime
     viewport" and "small map locks the camera to the map center".
7. **roadmap.md** (not committed per standing instruction) — dated
   corrective iteration note; P6-T1 evidence descriptions updated;
   counts unchanged. **README.md** — touch_debug documentation.

## F. Viewport verification (host-observed geometry, no device)

Probe (real scene, real limits) per window size:

| Window | Canvas (expand) | Camera center | Limits | Exposed margin |
|---|---|---|---|---|
| 1280x576 | 1600x720 | (672, 360) | -128..1472 / 0..768 | 8% per side, backdrop-covered |
| 960x540 | 1280x720 | (640, 360) | 0..1344 / 0..768 | none (clamped) |
| 1280x720 | 1280x720 | (640, 360) | 0..1344 / 0..768 | none (clamped) |
| 1600x900 | 1280x720 | (640, 360) | 0..1344 / 0..768 | none (clamped) |
| 2340x1080 | 1560x720 | (672, 360) | -108..1452 / 0..768 | 6.9% per side, backdrop-covered |

Before the fix, 1280x576 produced camera center (72, 360) with
gray_left_frac 0.455; after the fix the map is centered and fully
visible with the margin rendered as the intentional backdrop panel.
Restart at the last size reproduced the identical camera position (no
jump). Player on screen: true at every size.

Honest limitation: this is headless geometry verification against the
real scene graph, not rendered pixels. No host display stack was
installed and no screenshot-diff system was invented; actual visual
appearance (colors, legibility) remains for the developer to confirm on
their display or device.

## G. Regression results

Commands (final tree, exact):

- `timeout 15m /tmp/godot --headless --path . --import` -> exit 0
- `timeout 15m /tmp/godot --headless --path . --quit-after 180` ->
  boot OK (level generated, 5 lights, 2 enemies, 1 objective)
- `timeout 15m /tmp/godot --headless --path . res://tools/smoke_test.tscn`
  -> **SMOKE TEST: all checks passed — 241/241 PASS**
- `GODOT_BIN=/tmp/godot bash tools/validate_project.sh` -> OK (exit 0)

Totals: 214 preserved + 27 new = 241 checks; 2 legacy checks updated
in place (assertions of the corrected contract, not removed).

New checks cover: framing contract on small/large/mixed/offset maps;
live boot limits; camera inside limits; player visible at spawn;
wide-canvas full-map visibility (the 1280x576 defect class); backdrop
first-child + extent; boundary frame; HUD font >= 16; HUD inside
viewport; HUD never overlapping touch buttons; zone line never empty;
unrestricted state at spawn; input-mode help; objective/extraction
binding; touch overlay hidden headless, forced by touch_debug with
touch help text; no camera jump after restart; level switch recomputes
limits; player visible after switch; framing valid across
960x540/1280x720/1600x900/2340x1080/1280x576 canvases; teardown
cleanliness.

## H. Changed file audit

All changes in this iteration (nothing pre-existing was staged or
stashed): scripts/main.gd, scripts/level_generator.gd,
scripts/mobile_controls.gd, scenes/main.tscn, project.godot,
tools/smoke_test.gd, tools/layout_probe.gd (new), README.md,
roadmap.md (untracked by git by design). No changes to player speeds,
enemy AI, doors, terminals, mission progression, zones consequences,
level generation rules, audio/haptics, or Android export/signing.

## I. Complete roadmap snapshot (after this iteration)

- Phase 1 — Functional Project Foundation: [x] P1-T1 Project
  configuration, [x] P1-T2 Player controller, [x] P1-T3 Touch
  controls, [x] P1-T4 Level generator, [x] P1-T5 Stealth model v1,
  [x] P1-T6 Validation pipeline — 6/6.
- Phase 2 — Stealth and Visibility: [x] P2-T1 Dynamic lighting,
  [x] P2-T2 Advanced stealth visibility, [x] P2-T3 Noise propagation
  foundation, [x] P2-T4 Visibility meter and feedback, [x] P2-T5
  Regression and pipeline — 5/5.
- Phase 3 — Enemy AI: [x] P3-T1 Enemy scene and FSM skeleton,
  [x] P3-T2 Vision cones, [x] P3-T3 Noise reaction, [x] P3-T4
  Throttled AI and tests, [x] P3-T5 Grid placement and regression —
  5/5.
- Phase 4 — Level Variety: [x] P4-T1 Multiple layouts, doors,
  restricted zones, [x] P4-T2 Placement variety and seeds, [x] P4-T3
  Generator tests for every layout — 3/3.
- Phase 5 — Mission System: [x] P5-T1 Interactive terminals, [x]
  P5-T2 Objectives, restricted areas, extraction, [x] P5-T3 Mission
  manager and end states, [x] P5-T4 Mission loop tests — 4/4.
- Phase 6 — Mobile Gameplay Polish: [x] P6-T1 Camera smoothing and
  animation states (evidence updated by the 2026-10-23 corrective
  iteration), [x] P6-T2 HUD layout, detection meter UX, audio/haptic
  feedback — 2/2. Corrective iteration note added (root cause, files,
  evidence, limitations).
- Phase 7 — Android Optimization: [x] P7-T1 Profiling pass and
  behavior-preserving optimizations, [ ] P7-T2 Stable 60 FPS on
  mid-range hardware (device evidence) — 1/2.
- Phase 8 — APK Packaging and Device Testing: [ ] P8-T1 setup ->
  build -> install pipeline (host-verified to install step; install
  requires a physical device), [ ] P8-T2 Debug and release signing
  (debug verified v2+v3; release keystore pending user credentials),
  [ ] P8-T3 On-device gameplay verification (requires a physical
  device) — 0/3.

Total: 26/30 (P7-T2, P8-T1, P8-T2, P8-T3 open — all awaiting real
device evidence or user-supplied release credentials). Counts
recomputed and unchanged; no unrelated historical state was rewritten.
Roadmap re-read after the update.

## J. Definition of Done

- Layout defect diagnosed and corrected with runtime evidence: MET
  (headless geometry verification against the real scene).
- Regression suite extended and green: MET (241/241).
- Roadmap integrity: MET (dated corrective note, counts unchanged).
- Visual confirmation on a real display/device: NOT MET here —
  DEVICE-UNVERIFIED. The developer should re-run the game at 1280x576
  (or any landscape size) and confirm the composition visually.

## K. Git safety

Initial: clean tree at 5884e2e (no staged, unstaged or pre-existing
work). No reset, stash, clean or overwrite was performed; no force
push. Per the user's explicit live instruction, the remediation commit
was pushed to main (APK, keystore material and roadmap.md remain
excluded by .gitignore). Final index/tree state: committed and pushed;
working tree clean after the push.

## L. Final status

COMPLETED (host-side). Distinguish honestly:
- Host-observed rendering: none (headless environment; no display
  stack installed, none required).
- Headless geometry/behavior verification: all evidence above.
- Historical evidence: prior phases' recorded evidence preserved.
- Real-device behavior: NOT VERIFIED — on-device install, 60 FPS and
  visual confirmation remain open (P7-T2, P8-T1, P8-T2, P8-T3).

Debug APK rebuilt from the remediated tree (host-side, unchanged
signing/export configuration) and delivered alongside this report.
