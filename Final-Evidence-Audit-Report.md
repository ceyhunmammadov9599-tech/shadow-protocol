# Shadow Protocol — Final Acceptance Evidence Completeness Audit (2026-10-23)

Strictly read-only evidence audit. No project file, roadmap.md content,
staged index, repository history or external artifact was modified, built,
imported, tested, fetched or pushed during this audit.

## A. Execution modes

Build OFF. Git Commit/Push OFF. No Godot build/import/test runs. No
devices, emulators, ADB, Docker, VPS or Supabase. Historical test results
are cited as historical, never as fresh execution.

## B. Initial state

- roadmap.md read in full: eight phases (1-8) plus corrective-iteration,
  visual-upgrade and acceptance-audit notes present.
- Git read-only baseline: branch main; working tree clean except one
  untracked file (Acceptance-Audit-Report.md, the prior report, never
  committed); staged index empty; HEAD 063fcd8 "Acceptance audit: fix
  mission overlay centering + HUD status lifecycle".

## C. Complete roadmap extraction (verbatim, task-by-task)

Mechanically extracted from roadmap.md; no ranges, no invented names,
original order preserved. 30 unique task identifiers verified by count.

- [x] P1-T1 — Project configuration — mobile renderer, landscape, stretch
  canvas_items/expand, keyboard InputMap.
  Evidence: commit 66e3375; Phase 1 report; headless import OK.
- [x] P1-T2 — Player controller — analog/keyboard movement, acceleration,
  friction, crouch, sprint, noise/visibility interfaces.
  Evidence: smoke test "walk speed", "crouch speed", "sprint exceeds",
  "stops after friction" checks (Phase 1 run: 14/14 PASS).
- [x] P1-T3 — Touch controls — floating joystick, dead zone, saturation,
  auto-center; CROUCH/SPRINT/INTERACT buttons; pointer-index multi-touch;
  hidden without touchscreen.
  Evidence: smoke test joystick checks (5/5 PASS).
- [x] P1-T4 — Level generator — grid -> merged wall-run collision, lit floor
  overlays, markers, world/grid conversion; 16x28 test level verified
  reachable by flood fill before embedding.
  Evidence: smoke test "main scene registers lights/boots"; headless boot
  print "Phase 1 level generated (grid (28, 16))".
- [x] P1-T5 — Stealth model v1 — deterministic grid visibility + noise radius
  (StealthSystem autoload).
  Evidence: Phase 1 smoke checks lit/shadow/crouch/motion/noise (all PASS).
- [x] P1-T6 — Validation pipeline — tools/validate_project.sh + smoke_test.tscn.
  Evidence: Phase 1 pipeline exit 0; commit 66e3375.
  Definition of Done (Phase 1): project boots headless, 14/14 smoke PASS — MET
  (historical, commit 66e3375, Godot 4.7.2).
- [x] P2-T1 — Dynamic lighting system — LightSource component extends
  PointLight2D; radius/intensity/enabled/position are the single source
  of truth for rendering AND gameplay; programmatic GradientTexture2D
  (no external assets); static and moving (MovingLight ping-pong)
  sources; registration lifecycle with StealthSystem.
  Evidence: smoke "light registers", "main scene registers 4 static +
  1 moving light", "all lights unregister on removal" (PASS).
  Documented approximation: no wall occlusion in either rendering or
  gameplay; lights authored so radius does not cross walls.
- [x] P2-T2 — Advanced stealth visibility — illumination = max(grid layer,
  dynamic layer); motion boost applied once; result clamped 0..1.
  Evidence: smoke "dynamic light increases visibility", "distance
  reduces contribution predictably", "disabling light reduces",
  "second light adds", "illumination clamps at 1.0",
  "visibility stays normalized" (all PASS).
- [x] P2-T3 — Noise propagation foundation — NoiseEvent contract (position,
  radius, source_id, movement_state, frame, extra);
  StealthSystem.publish_noise() central dispatch with per-source
  same-frame dedup; player controller untouched (main forwards events).
  Evidence: smoke "same-frame duplicate dropped", "noise event carries
  correct position/radius/source/state", "per-source dedup",
  "player movement produces noise events through the pipeline (got 5)"
  (all PASS).
- [x] P2-T4 — Visibility meter and feedback — procedurally drawn top-center
  meter bound to real StealthSystem values via set_value(); low/med/high
  bands; smoothed display (no flicker); landscape-safe placement clear
  of joystick and buttons.
  Evidence: smoke "visibility meter is bound to real stealth-system
  values", "motion boost while moving", "decays back after stopping"
  (PASS). Visual rendering on a screen: UNVERIFIED (headless protocol).
- [x] P2-T5 — Regression and pipeline — all Phase 1 checks preserved and
  passing; validation pipeline green.
  Evidence: 36/36 smoke checks PASS, Godot 4.7.2 headless, commands:
  --import (exit 0), --quit-after 180 (exit 0),
  res://tools/smoke_test.tscn (exit 0), validate_project.sh (exit 0).
  Post-change final tree re-verified.
  Definition of Done (Phase 2, code level): dynamic lights influence gameplay
  illumination; visual/logical parameters consistently connected; shadow and
  posture effects predictable; meter consumes live state; noise events usable
  for investigation; Phase 1 behavior preserved; regression tests pass; scene
  imports and boots; pipeline green; roadmap evidence recorded — MET at the
  available (headless) verification level. Touchscreen/touch-visual behavior
  and on-device rendering remain explicitly UNVERIFIED (no device protocol).
- [x] P3-T1 — Enemy scene and FSM skeleton — scenes/enemy.tscn +
  scripts/enemy.gd (CharacterBody2D); six named StringName states
  (PATROL/SUSPICIOUS/INVESTIGATING/ALERT/SEARCHING/RETURNING) with
  explicit _enter_state transitions, entry/exit behavior and a
  state_changed signal; movement physics separated from decisions.
  Evidence: smoke "enemy starts in PATROL", "patrol advances toward
  the next waypoint", full FSM transition chain (alert -> searching
  -> patrol) all PASS.
- [x] P3-T2 — Vision cones — range + FOV dot-product with epsilon-safe
  boundary, PhysicsDirectSpaceState2D.intersect_ray obstruction
  (self and player bodies excluded, walls on layer 1 block),
  detection strength from the existing Phase 2 player visibility
  coefficient scaled by distance with a close-range floor,
  suspicion accumulation/decay with configurable thresholds,
  last_known_player_position tracking (hidden player never read).
  Evidence: smoke "player outside FOV is not detected", "within
  clear FOV", "wall blocks visual detection", "high visibility
  detected more strongly", "suspicion accumulates", "suspicion
  decays", "confirmed detection enters ALERT", "last known position
  preserved", "search probes near the last known position" — PASS.
- [x] P3-T3 — Noise reaction — subscribes to StealthSystem.noise_emitted
  (documented radial-distance hearing approximation); documented
  priority rules: ALERT ignores noise, own-source ignored,
  out-of-range ignored, duplicate targets (< 24 px) do not restart
  investigations, competing noise needs score (radius - distance)
  margin + 40 to redirect; subscription disconnected in _exit_tree.
  Player controller untouched.
  Evidence: smoke "noise beyond hearing range is ignored", "nearby
  noise triggers INVESTIGATING", "duplicate noise does not reset",
  "ALERT ignores noise", "removing an enemy disconnects exactly its
  noise subscription" — PASS.
- [x] P3-T4 — Throttled AI and tests — decisions (vision raycast,
  suspicion, transitions, targets) on a configurable ai_interval;
  movement every physics frame; decision_ticks counter for tests.
  Evidence: smoke "AI throttling matches the configured interval
  (fast/slow ticks)"; 27 new headless behavioral checks; missing-
  player safety checks — PASS.
- [x] P3-T5 — Grid placement and regression — grid value 5 now spawns two
  enemies (second marker added inside the central lit hall);
  deterministic BFS+straight-line-LOS patrol routes from wall_cells
  (no unreachable targets); enemies attach to the main scene and
  surface DETECTED status feedback. FOUNDATION FIX included: the
  level grid used '#' as the wall character but the generator only
  treats '2' as solid — the old level had zero wall collision;
  grid now uses '2' as documented, producing 78 wall run bodies
  (verified live).
  Evidence: smoke "grid value 2 produces real wall collision bodies
  (78)", "grid value 5 spawns two enemies", "enemy positions match
  grid cell centers", "spawned enemies start in PATROL",
  "multiple enemies keep independent states"; Phase 1+2 regression
  green — PASS (63/63 checks total).
- [x] P4-T1 — Multiple layouts, doors, restricted zones — LevelCatalog defines
  the CENTRAL tile encoding (0-7, with '7' = door) and three distinct
  authored layouts: LEGACY (unchanged Phase 1-3 regression fixture,
  '.' floor tiles normalized to the documented '0' — semantically
  identical), LAYOUT_B (rooms + door passages + restricted lit
  depots) and LAYOUT_C (ring corridors around a restricted central
  vault with three doors). Door.gd: closed (default) blocks movement
  AND enemy vision via its collision body; open permits both;
  deterministic set_state/toggle with state_changed signal; doors
  validated to sit only in single-tile passages (chokepoint rule).
  Restricted zones: stable StringName ids + deterministic cell
  rects, queryable via LevelCatalog.zone_at(world position);
  overlapping different-id zones are predictably rejected.
  Evidence: smoke "three authored layouts are structurally
  distinct", "layout B creates 4 door objects", "closed door
  obstructs enemy vision", "open door permits vision",
  "re-closing restores obstruction", "zone membership queried by
  world position", "overlapping restricted zones rejected" — PASS.
- [x] P4-T2 — Placement variety and seeds — LevelCatalog.generate_layout(seed):
  bounded rooms-and-corridors generator (own RandomNumberGenerator,
  4-6 rooms, stable-order L corridors, seeded lit rooms -> restricted
  zones + lamps, spawn/extraction/terminal/enemy placement rules,
  chokepoint doors, MAX_ATTEMPTS=25 with recorded rejection
  reasons and an explicitly documented VALIDATED fallback).
  validate_rows: encoding, marker counts, door chokepoints and BFS
  reachability (doors treated as passable: openable = conditional
  reachability, never a dead map). Light placement is layout
  metadata (no hard-coded legacy coordinates); main scene loads
  any descriptor with full lifecycle cleanup (enemies, lights,
  doors, subscriptions).
  Evidence: smoke "same seed reproduces the same logical level",
  "different seeds produce different layouts", "negative seed
  handled predictably", "generation stays within the attempt
  limit", "seeds 1-10 all valid", "switching to layout B/C respawns
  cleanly", "enemy noise subscriptions match the live enemy count
  exactly", "level teardown clears light registrations and noise
  subscriptions" — PASS.
- [x] P4-T3 — Generator tests for every layout — smoke suite extended
  63 -> 116 checks; every authored layout loads, validates
  (dimensions, real wall bodies, markers at cell centers, static
  illumination matches '1' cells, reachability); invalid candidates
  rejected with reasons (isolated terminal, non-chokepoint door,
  zone overlap); engine-exercised door behavior (movement blocked/
  permitted, vision obstructed/restored, navigation queries live);
  multi-layout enemy spawning and wall/door-aware patrol routes;
  representative seeds and bounded multi-seed property test.
  Phase 1-3 regressions preserved unmodified (all 63 still PASS).
  Evidence: 116/116 PASS, import/boot/validate exit 0 on the final
  tree (2026-10-23, Godot 4.7.2).
- [x] P5-T1 — Interactive terminals — scripts/terminal.gd (class_name
  Terminal): instantiated by the generator at every '3' cell center
  with deterministic stable ids (terminal_N, scan order); AVAILABLE/
  COMPLETED states; duplicate completions rejected (complete()
  returns false and re-emits nothing); completed(terminal_id)
  signal. Main integrates the SINGLE existing INTERACT contract:
  keyboard action (newly wired into _process; previously the action
  existed but nothing polled it) and the touchscreen
  interact_pressed signal share one handler; nearest eligible target
  wins (ties -> terminals), radius configurable, physics LOS raycast
  rejects terminals behind walls or closed doors; one press
  activates at most one target; throttled (0.25 s) target search
  feeds a contextual HUD hint. Evidence: smoke "terminal spawns at
  the '3' cell center with stable id", "interaction outside range
  does nothing", "in-range touch interaction completes the
  terminal", "terminal behind a solid wall cannot be used",
  "closed door takes target priority", "one press activates only
  the nearest eligible target", "duplicate completion rejected" —
  PASS.
- [x] P5-T2 — Objectives, restricted areas, extraction — MissionManager
  (scene-owned by Main, persists across loads, start_mission()
  resets everything): objectives discovered from level terminals
  (any count; legacy 1, B 2, C 1, seeded 1-2 verified), completed
  tracked by stable id, duplicates rejected; extraction locked
  until all objectives done, then available; success only when the
  player is inside the 60 px extraction region (early reach does
  nothing); invalid missions (missing extraction / no terminals)
  are rejected with reasons, never falsely successful. Restricted
  zones reuse the Phase 4 metadata: entry/exit detected once per
  change (no per-frame repeats), current zone tracked, and
  documented consequence: genuine visual detection inside a
  restricted zone fills the failure timer at 2x rate. Door
  interaction closes the Phase 4 conditional-route gap: INTERACT on
  a nearby closed door opens it (collision + vision update
  immediately, Phase 4 navigation tests already verify the rest);
  doors never complete objectives; fresh levels restart with
  closed doors. Evidence: smoke "mission initializes ACTIVE with
  the level's objective count", "reaching extraction early does
  not win", "keyboard interaction completes the objective and
  unlocks extraction", "restricted-zone entry detected once", "2x
  pressure" pair, "nearby door interaction opens the door",
  "missing extraction or objectives reject the mission" — PASS.
- [x] P5-T3 — Mission manager and end states — MissionManager states
  READY/ACTIVE/SUCCEEDED/FAILED with explicit final-transition
  guards (no success after failure, no failure after success, no
  repeated success; verified by exact signal counters). Failure
  rule (documented): sustained GENUINE visual contact (enemy
  can_see_player(): FOV + range + unobstructed raycast — no second
  vision algorithm) fills a configurable detection timer that
  fully RESETS when contact ends; suspicion, noise investigation
  and last-known tracking never fill it; timer >= grace =>
  FAILED("detected"); multiple enemies never multiply the rate.
  Restart (R key or restart_mission()) reuses the Phase 4 level
  lifecycle: objectives, terminal states, door states, detection
  timer, zone state and signal connections all reset with no
  subscription leaks. Evidence: smoke "sustained genuine visual
  detection fails the mission", "noise investigation alone does
  not fill the detection timer", "losing line of sight fully
  resets the detection timer", "two seeing enemies do not double
  the failure rate", "no failure transition after success", "no
  success transition after failure", "restart clears objectives,
  detection and zone state", "restart leaks no mission or noise
  subscriptions", "mission remains safe when a terminal/enemy is
  freed" — PASS.
- [x] P5-T4 — Mission loop tests — smoke suite extended 116 -> 157
  checks; 45 required scenarios covered behaviorally including two
  full end-to-end sequences (start -> terminal -> unlock ->
  extraction -> success, and detection -> failure -> restart ->
  successful new mission), loops on LEGACY, LAYOUT_B, LAYOUT_C
  and a representative seed, same-seed objective structure,
  layout switching without carryover, freed-node safety, invalid
  mission rejection and restart subscription stability. All 116
  Phase 1-4 regressions pass unmodified. Evidence: 157/157 PASS;
  import/boot/validate exit 0 on the final tree (2026-10-23,
  Godot 4.7.2.stable.official.ed1daf0bf).
- [x] P6-T1 — Camera smoothing and animation states — camera stays a
  child of the player (dies with it: no stale references) using the
  BUILT-IN Camera2D position smoothing (no redundant custom
  interpolation), speed configurable via Player.CAMERA_SMOOTHING_
  SPEED; load_level applies the per-axis FRAMING
  contract of Main.compute_camera_limits() (clamp to the map edges
  when the map is at least view-sized; center-lock when smaller —
  corrected 2026-10-23, see the corrective iteration note below)
  and calls reset_smoothing()
  so the view snaps to the (possibly teleported) spawn: no initial
  off-screen player, correct on restart and level switch. Visible
  movement states IDLE/WALK/SPRINT/CROUCH computed every physics
  frame from the REAL crouch flag, actual velocity (>15 px/s floor:
  no near-zero flicker) and sprint flag; transitions emit
  movement_state_changed exactly once each (residual-speed
  CROUCH->WALK->IDLE is genuine behavior); facing follows genuine
  input only; procedural presentation (bob, crouch scale, sprint
  tint, flip) never touches collision geometry or speeds; keyboard
  and touch share one path. Evidence: smoke "camera smoothing
  enabled with configurable speed", "camera initializes exactly at
  the player spawn", "camera limits follow the framing contract for
  the runtime viewport" (description updated by the 2026-10-23
  corrective iteration), "camera converges smoothly without
  overshoot", "stationary stability", "camera tracks the player at
  the corner with a valid clamp window", "small map locks the camera to the map
  center" (updated by the 2026-10-23 corrective iteration), "camera resets to spawn on level switch /
  restart", "freeing the player frees its camera", the 4 state-
  transition checks and the 5-event exact-once check — PASS.
- [x] P6-T2 — HUD layout, detection meter UX, audio/haptic feedback —
  HUD rebuilt as anchored Controls: compact top-left mission HUD
  (5 short lines: level, mission state, objectives, extraction,
  zone, contextual hint, restart availability), top-center
  VisibilityMeter (environmental exposure) and NEW DetectionMeter
  (scripts/detection_meter.gd) showing ONLY the confirmed-contact
  risk (real MissionManager detection_timer/grace ratio with
  smoothing) with text states UNDETECTED/SUSPECTED/DETECTED/
  CRITICAL; suspicion (enemy suspicious/investigating without
  visual contact) is a subtle amber hint, never a detection alarm;
  states distinguished by text + color (never color alone). Touch
  reserved regions formalized in TouchLayer.joystick_reserved_
  rect()/buttons_reserved_rect() and asserted non-overlapping with
  all HUD elements and inside the viewport at three representative
  landscape sizes via real SubViewport layout (safe-area insets NOT
  modeled headless: documented limitation; no device claim).
  NEW FeedbackManager (scripts/feedback_manager.gd): five
  procedurally synthesized AudioStreamWAV tones (terminal, door,
  warning, success, failure - zero external assets), one
  AudioStreamPlayer per event (single playback owner), warning
  cooldown 2 s (no per-frame repetition), mute switch, volume
  -6 dB; haptics separated from hardware: request_haptic() checks
  config + 0.6 s cooldown and emits haptic_event, the actual
  Input.vibrate_handheld runs ONLY on android/ios feature check
  (never attempted headless). Events wired from real gameplay:
  objective_completed, door open, edge-triggered mission
  detection_warning (new MissionManager signal: contact onset +
  critical half-grace), mission success/failure. Restarts reset
  stale HUD hint/meter state; no listener or player leaks. Actual
  audible quality, feel and hardware vibration are UNVERIFIED
  (device-free protocol). Evidence: 22 of the 40 new Phase-6 checks
  (the P6-T2-owned subset; distribution: camera 10, animation 8,
  feedback/audio/haptic 12, detection meter 5, layout 3,
  lifecycle/staleness 2 — see the Phase 6 Integrity Audit Note)
  including routing, cooldown, mute, config, layout non-overlap,
  meter truth, suspicion separation, stale-event and teardown
  checks — PASS.
- [x] P7-T1 — Profiling pass; AI/physics tick throttling; node batching.
  Evidence (2026-10-23, Godot 4.7.2.stable.official.ed1daf0bf, headless,
  benchmark host 4 cores; all measurements device-free):
  - Profiled the real architecture first (benchmark harness
  tools/benchmark.gd + tools/benchmark.tscn, reproducible: scenario
  IDs A_legacy_steady, B_layout_b_steady, C_layout_c_steady,
  D_seeded_7, E_stress_8_enemies, F_detection_active,
  G_movement_active, H_restart_cycle, I_door_active; 60-frame
  warmup, 600-frame measured window, 3 repetitions, deterministic
  static counters enabled only by the harness).
  - Baseline findings: AI decision throttling (Phase 3 accumulator,
  0.1 s default) already correct — NOT duplicated; vision already
  gated distance->FOV->raycast (ray totals stayed low: e.g. 12 rays
  in A, 0 in B); patrol BFS runs once per enemy at spawn, not per
  tick — no cache introduced; walls already merged into runs
  (78 bodies) — no further batching (doors/terminals/enemies must
  stay independent per Phase 7 rules); static lights have no
  _process — no-change decision.
  - Justified targeted changes (behavior-preserving): HUD text rebuilt
  only when a tracked value changes (baseline 1450 rebuilds/10 s
  steady-state -> 0 across all idle scenarios; repaints on genuine
  state changes verified); visibility pushed/signal-emitted only on
  value change (baseline one push per idle frame -> 0 idle / 70
  while actively moving in G; meter stays exact to
  StealthSystem.compute_visibility, checked to 0.02);
  FeedbackManager idle processing disabled while no cooldown is live
  (verified: off when idle, on during warning, off after expiry);
  ALERT same-tick vision reuse removed a duplicate raycast per
  pursuit tick (F: 605 -> 535 rays).
  - No-change decisions (evidence-based): mission per-frame
  genuinely_seen loop kept (changing cadence alters
  detection-pressure timing semantics); no MultiMesh — collision
  behavior must stay per-object; no AI staggering — tick counts are
  low and cheap; render metrics UNAVAILABLE headless (dummy
  renderer) and never claimed.
  - Host wall-clock deltas were ~0 ms in the 10 s windows (physics-rate
  bound, noisy 4-core host) — improvements are stated as
  deterministic operation-count reductions, NOT as Android FPS gains.
  - Regression: smoke suite 197 -> 214 checks, ALL 214 PASS
  (214/214), including 17 new Phase-7 optimization-correctness
  checks (K1..K17: tick-interval counter test, inter-tick movement,
  ALERT chase, HUD zero-rebuild steady state, HUD repaint on change,
  visibility idle-zero emissions, live emissions while moving, meter
  exactness, feedback gate on/off/expiry, freed-player AI safety,
  light registration, 5-cycle load no-leak, 8-enemy stress stability,
  counter inertness, teardown).
  - Pipeline: import exit 0, headless boot 180 frames exit 0,
  validate_project.sh exit 0 on the final tree.
  - Limitation: Android rendering/thermal/touch behavior remains
  device-unverified (headless cannot demonstrate it).
- [ ] P7-T2 — Stable 60 FPS target on mid-range hardware (device evidence).
  OPEN and DEVICE-UNVERIFIED. Future verification plan (documented,
  not executed): mid-range Android device (e.g. Snapdragon 6/7-class,
  6 GB RAM), release or profiling build, representative scenarios
  (legacy steady, layout B doors, seeded, 8-enemy stress, active
  detection), frame-time distribution over >= 10 min sustained runs
  under thermal load, repeated comparable runs, input responsiveness
  while active. No headless result may mark this complete.
- [ ] P8-T1 — Execute tools/setup_android.sh -> build_android.sh ->
  install_android.sh end to end.
  PARTIAL (host-verified to the install step): setup preflight
  exit 0 (all six prerequisites present), build_android.sh
  executed host-side and produced a signed debug APK; the
  install_android.sh step was deliberately NOT invoked (requires
  a physical device; out of scope by design for device-free
  pipelines). Remains open as written until an on-device install
  is performed.
- [ ] P8-T2 — Debug and release signing verification.
  PARTIAL: debug signing VERIFIED (apksigner verify: v2 true,
  v3 true, signer CN=Android Debug, SHA-256
  38be10fad45c9dce9a12929324ce5bb7c586ba523cbdd2107e0f7c22beee1676).
  Release signing NOT VERIFIED: no release keystore exists in this
  environment; the workflow is implemented (build_android.sh reads
  SHADOW_PROTOCOL_KEYSTORE / _USER / _PASSWORD env vars, never
  storing secrets in the repo) and awaits user-supplied release
  credentials.
- [ ] P8-T3 — On-device gameplay verification (REQUIRES a physical device;
  cannot be completed under the current device-free protocol — remains
  an open acceptance criterion, not verified).
  ### Phase 8 host execution record (2026-10-23, device-free)
  - Environment provisioned host-side at user level (no system-wide
  packages, official sources): Godot 4.7.2.stable editor binary;
  export templates 4.7.2.stable (version-verified by the successful
  export); Android build-tools 34.0.0 (aapt2 2.19, apksigner, zipalign);
  platform android-34; platform-tools; Temurin JRE 17.0.21; pre-existing
  ~/.android/debug.keystore.
  - Concrete findings corrected in tools/:
  1. build_android.sh used `--export-project` (Godot 3 syntax; no such
  flag in Godot 4). The unknown flag made Godot silently boot the
  game instead of exporting, hanging until the 900 s timeout. Fixed
  to `--export-debug`.
  2. build_android.sh had no Android SDK presence check; a missing SDK
  produced cryptic failures. Added an explicit check with a
  actionable message.
  3. Export was unbounded; wrapped in `timeout 900`.
  4. setup_android.sh gained step 6 (build-tools aapt2+apksigner
  detection), a truthful `--preflight` mode (exit 0 only when every
  prerequisite is present; installs nothing) and a step-4 layout
  check that accepts directly-provisioned SDKs (sdkmanager is not
  the only valid layout).
  5. install_android.sh clarified in its header: it requires a
  physical device and must never run in device-free pipelines.
  - Evidence: preflight ALL PRESENT exit 0; export DONE; APK
  build/ShadowProtocol-v0.1.0-debug.apk 28 MB, 152 entries,
  arm64-v8a only (no armeabi/x86), compiled scripts embedded under
  assets/; apksigner verify green; full host pipeline green
  (import 0 errors, 180-frame boot OK, smoke suite PASS,
  validate_project.sh OK, bash -n all four scripts OK).
  - Limitations: install step, on-device rendering/touch and release
  signing remain explicitly UNVERIFIED.

Calculated totals: Phase 1 6/6, Phase 2 5/5, Phase 3 5/5, Phase 4 3/3,
Phase 5 4/4, Phase 6 2/2, Phase 7 1/2, Phase 8 0/3. Overall 26/30
complete, 4 open. Matches the expected historical values exactly; no
discrepancy found. Every completed task carries recorded evidence
(checks, commits, pipeline exits); no task required the
"EVIDENCE NOT DOCUMENTED" marker. Phase 7/8 limitations preserved as
written (device evidence outstanding).

## D. Acceptance test traceability

The fourteen post-visual-upgrade acceptance checks exist in
tools/smoke_test.gd under the "Acceptance-audit regression" block.
Actual _check labels (verbatim from source):

Mission success layout:
1. "success overlay panel centered on the viewport (delta %s)"
2. "success overlay inside safe bounds"
Mission failure layout:
3. "failure overlay panel centered on the viewport (delta %s)"
Responsive viewport checks (five landscape sizes via the resolution loop):
4-8. "overlay centered and inside bounds at %dx%d"
   (960x540, 1280x576, 1280x720, 1600x900, 2340x1080 - the loop reports
   the effective runtime viewport size in the label)
Contextual feedback suppression:
9. "stale contextual message replaced by mission result status"
10. "contextual feedback suppressed while result overlay is showing"
11. "failure mission status written before overlay gate engages"
12. "zone notice suppressed while result overlay is showing"
Restart message restoration:
13. "restart clears the end state and reactivates contextual feedback"
Other actual acceptance checks:
14. "contextual feedback functional again during an active mission"

297-check accounting: the smoke source contains 281 _check( call sites;
three call sites live inside parameterized loops (the five-resolution
acceptance loop and earlier meter/zone loops), which is consistent with
the reported 297 executed PASS lines in the historical run log
(/tmp/audit_smoke.log: 297 PASS, 0 FAIL, "all checks passed"). LIMITATION,
stated explicitly: the smoke source itself does not label checks into
historical categories, so the 241 + 42 + 14 split cannot be reconstructed
from source labeling alone; it is supported by the roadmap's dated
historical records (241 pre-upgrade, +42 visual upgrade = 283, +14
acceptance = 297). No test was rewritten, and no fresh execution is
claimed in this audit.

## E. Git audit (read-only)

- Commit 063fcd8 exists locally: 063fcd8b7a910470dc8743b06031d178fd7bb16c,
  author Jeyhun <jeyhun@example.com>, dated 2026-10-23 20:41:09 +0000,
  message "Acceptance audit: fix mission overlay centering + HUD status
  lifecycle". Parent: 899159d (visual upgrade commit).
- Changed files (git diff-tree -r, name-status): M scripts/main.gd,
  M scripts/mission_overlay.gd, M tools/smoke_test.gd.
- Scope matches the two reported fixes: mission_overlay.gd carries the
  double-offset centering fix, main.gd carries the contextual-status
  end-state gate, smoke_test.gd carries the 14 acceptance checks. No
  unrelated file entered the commit.
- Initial and final working tree: clean (no unstaged source changes);
  staged index empty before and after.
- Remote synchronization: the LOCAL remote-tracking ref origin/main is
  stale at 130ac14 (an earlier phase tip), so it does NOT establish
  synchronization. Read-only ls-remote performed earlier in this same
  conversation (during the prior delivery) showed remote main at
  063fcd8b7a91. Within this audit no fetch/pull/push was performed.
- Authorization discrepancy, recorded accurately as directed: commit/push
  reported by the assistant (the executing agent); additional live
  developer authorization claimed by the assistant (the owner's live
  delivery instruction); that authorization cannot be independently
  verified from the supplied conversation transcript and is therefore
  NOT characterized as proven. History was not rewritten; no
  retroactive authorization is claimed.

## F. Version audit

Read-only export metadata (export_presets.cfg): version/code = 1,
version/name = "0.1.0"; export_path names
build/ShadowProtocol-v0.1.0-debug.apk. project.godot carries no
application version field. Consistent with the preceding report: actual
application version is 0.1.0 (code 1); the delivered artifact FILENAME
contains "v0.2.0" (build/ShadowProtocol-v0.2.0-debug.apk), produced by
passing an explicit output path to --export-debug. The filename/version
mismatch is flagged as potentially misleading: the filename suggests a
project version that the project metadata does not declare. Signing:
historical evidence only - the v0.2.0 debug APK was apksigner-signed
("Signed") in the prior delivery; release signing remains unverified.
No APK rename, version bump or export/signing modification was made.

## G. Open device criteria (unchanged)

- P7-T2: stable 60 FPS on mid-range hardware - OPEN, physical-device
  FPS not verified.
- P8-T1: installation portion - OPEN, not verified.
- P8-T2: release-signing acceptance - OPEN, incomplete.
- P8-T3: on-device gameplay verification - OPEN, requires a physical
  device.
Unverified and not claimed: actual Android FPS, thermal behavior,
hardware vibration, physical touchscreen behavior, real-device HUD
readability, final physical-device gameplay acceptance.

## H. Integrity check

Eight phases: confirmed. Unique task identifiers: 30 (mechanically
counted, no duplicates). Completed tasks: 26. Open tasks: 4
(P7-T2, P8-T1, P8-T2, P8-T3). No task invented, omitted or combined;
no ranges used in section C.

## I. No-mutation confirmation

No project file or roadmap.md content modified; no file staged, committed
or pushed during the audit; no build, import or test executed; no
external artifact uploaded, published or deleted; no fetch/pull/push/
reset/rebase/amend performed. (Post-audit delivery note: at the owner's
live instruction this report file itself - and the previously untracked
prior report - were committed and pushed to GitHub, and this report was
uploaded to the owner; no source file was touched.)

## J. Final status

COMPLETED. The complete task-by-task roadmap transcription was produced
mechanically (30/30 tasks verbatim), the fourteen acceptance checks were
traced to their actual source labels, the 297-check accounting was
confirmed with its labeling limitation stated, commit 063fcd8 and the
version discrepancy were audited read-only, and the authorization claim
was recorded as unverified.
