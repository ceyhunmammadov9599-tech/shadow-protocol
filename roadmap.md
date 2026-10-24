# Shadow Protocol — Internal Roadmap

Development tracking document. Lives in the project root. Since the
2026-10-24 complete-backup directive it IS committed to the repository
(commits 57855a1/fd9d331; supersedes the earlier not-committed rule).
Verify, do not assume.

Current focus: Phase 8 — Release Signing & Delivery (P8-T1/P8-T2/P8-T3
open; P7-T1 complete at code level, P7-T2 awaits real-device evidence).
(Corrected 2026-10-24: the previous intro metadata still said "Phase 7"
and "not committed" after the Phase 8 backup work — demonstrably stale
statements, historical evidence below is preserved unchanged.)

Legend: [x] complete with recorded evidence · [ ] open

## Phase 1 — Functional Project Foundation (COMPLETE)

- [x] P1-T1 Project configuration — mobile renderer, landscape, stretch
      canvas_items/expand, keyboard InputMap.
      Evidence: commit 66e3375; Phase 1 report; headless import OK.
- [x] P1-T2 Player controller — analog/keyboard movement, acceleration,
      friction, crouch, sprint, noise/visibility interfaces.
      Evidence: smoke test "walk speed", "crouch speed", "sprint exceeds",
      "stops after friction" checks (Phase 1 run: 14/14 PASS).
- [x] P1-T3 Touch controls — floating joystick, dead zone, saturation,
      auto-center; CROUCH/SPRINT/INTERACT buttons; pointer-index multi-touch;
      hidden without touchscreen.
      Evidence: smoke test joystick checks (5/5 PASS).
- [x] P1-T4 Level generator — grid -> merged wall-run collision, lit floor
      overlays, markers, world/grid conversion; 16x28 test level verified
      reachable by flood fill before embedding.
      Evidence: smoke test "main scene registers lights/boots"; headless boot
      print "Phase 1 level generated (grid (28, 16))".
- [x] P1-T5 Stealth model v1 — deterministic grid visibility + noise radius
      (StealthSystem autoload).
      Evidence: Phase 1 smoke checks lit/shadow/crouch/motion/noise (all PASS).
- [x] P1-T6 Validation pipeline — tools/validate_project.sh + smoke_test.tscn.
      Evidence: Phase 1 pipeline exit 0; commit 66e3375.

Definition of Done (Phase 1): project boots headless, 14/14 smoke PASS — MET
(historical, commit 66e3375, Godot 4.7.2).

## Phase 2 — Stealth and Visibility (COMPLETE at code level)

- [x] P2-T1 Dynamic lighting system — LightSource component extends
      PointLight2D; radius/intensity/enabled/position are the single source
      of truth for rendering AND gameplay; programmatic GradientTexture2D
      (no external assets); static and moving (MovingLight ping-pong)
      sources; registration lifecycle with StealthSystem.
      Evidence: smoke "light registers", "main scene registers 4 static +
      1 moving light", "all lights unregister on removal" (PASS).
      Documented approximation: no wall occlusion in either rendering or
      gameplay; lights authored so radius does not cross walls.
- [x] P2-T2 Advanced stealth visibility — illumination = max(grid layer,
      dynamic layer); motion boost applied once; result clamped 0..1.
      Evidence: smoke "dynamic light increases visibility", "distance
      reduces contribution predictably", "disabling light reduces",
      "second light adds", "illumination clamps at 1.0",
      "visibility stays normalized" (all PASS).
- [x] P2-T3 Noise propagation foundation — NoiseEvent contract (position,
      radius, source_id, movement_state, frame, extra);
      StealthSystem.publish_noise() central dispatch with per-source
      same-frame dedup; player controller untouched (main forwards events).
      Evidence: smoke "same-frame duplicate dropped", "noise event carries
      correct position/radius/source/state", "per-source dedup",
      "player movement produces noise events through the pipeline (got 5)"
      (all PASS).
- [x] P2-T4 Visibility meter and feedback — procedurally drawn top-center
      meter bound to real StealthSystem values via set_value(); low/med/high
      bands; smoothed display (no flicker); landscape-safe placement clear
      of joystick and buttons.
      Evidence: smoke "visibility meter is bound to real stealth-system
      values", "motion boost while moving", "decays back after stopping"
      (PASS). Visual rendering on a screen: UNVERIFIED (headless protocol).
- [x] P2-T5 Regression and pipeline — all Phase 1 checks preserved and
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

## Phase 3 — Enemy Artificial Intelligence (COMPLETE at code level)

- [x] P3-T1 Enemy scene and FSM skeleton — scenes/enemy.tscn +
      scripts/enemy.gd (CharacterBody2D); six named StringName states
      (PATROL/SUSPICIOUS/INVESTIGATING/ALERT/SEARCHING/RETURNING) with
      explicit _enter_state transitions, entry/exit behavior and a
      state_changed signal; movement physics separated from decisions.
      Evidence: smoke "enemy starts in PATROL", "patrol advances toward
      the next waypoint", full FSM transition chain (alert -> searching
      -> patrol) all PASS.
- [x] P3-T2 Vision cones — range + FOV dot-product with epsilon-safe
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
- [x] P3-T3 Noise reaction — subscribes to StealthSystem.noise_emitted
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
- [x] P3-T4 Throttled AI and tests — decisions (vision raycast,
      suspicion, transitions, targets) on a configurable ai_interval;
      movement every physics frame; decision_ticks counter for tests.
      Evidence: smoke "AI throttling matches the configured interval
      (fast/slow ticks)"; 27 new headless behavioral checks; missing-
      player safety checks — PASS.
- [x] P3-T5 Grid placement and regression — grid value 5 now spawns two
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

## Phase 4 — Procedural Level Generation (COMPLETE at code level)

- [x] P4-T1 Multiple layouts, doors, restricted zones — LevelCatalog defines
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
- [x] P4-T2 Placement variety and seeds — LevelCatalog.generate_layout(seed):
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
- [x] P4-T3 Generator tests for every layout — smoke suite extended
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

## Phase 5 — Mission Gameplay (COMPLETE at code level)

- [x] P5-T1 Interactive terminals — scripts/terminal.gd (class_name
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
- [x] P5-T2 Objectives, restricted areas, extraction — MissionManager
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
- [x] P5-T3 Mission manager and end states — MissionManager states
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
- [x] P5-T4 Mission loop tests — smoke suite extended 116 -> 157
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

## Phase 6 — Mobile Gameplay Polish (COMPLETE at code level)

- [x] P6-T1 Camera smoothing and animation states — camera stays a
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
- [x] P6-T2 HUD layout, detection meter UX, audio/haptic feedback —
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

## Phase 6 Corrective Iteration Note (2026-10-23, runtime layout remediation)

A real 1280x576 runtime screenshot showed ~45% of the screen as an unused
gray band on the left with the level pushed right and the player at the
level's upper-left. Runtime-verified root cause: under canvas_items/expand
a 1280x576 window renders a 1600x720 canvas; the legacy map (1344x768) is
NARROWER than the canvas on x, and P6-T1's "unlimited limits for maps
smaller than the view" fallback let the camera follow the spawn-side
player (x=72) freely, so the view extended 728 px past the map's left
edge into the raw clear color (probe: gray_left_frac 0.455, camera
center (72, 360), x-limits +/-1000000). NOT a smoothing, spawn or
transform defect; y was correctly clamped.

Corrective changes (no new phase/task; gameplay systems untouched):
- scripts/main.gd: new static Main.compute_camera_limits() — per-axis
  framing contract (map >= view: clamp to map edges; map < view: lock to
  map center); load_level applies it; HUD zone line now states
  "none (unrestricted)" instead of an empty Zone label; the help line
  is input-mode aware (touch vs keyboard).
- scripts/level_generator.gd: coherent "site grounds" backdrop drawn
  behind the map (bounds + 640 px margin) and a thin boundary frame on
  the playable bounds, so any exposed margin reads as intentional
  composition instead of raw background.
- scenes/main.tscn: HUD font 14 -> 16 px, HUD box enlarged, HUD
  mouse-transparent.
- scripts/mobile_controls.gd + project.godot: explicit
  shadow_protocol/touch_debug setting (default false) forces the touch
  overlay for desktop layout testing; real-device detection rules
  unchanged (touchscreen or Android).
- tools/layout_probe.gd: new device-free layout diagnostic boots the
  real scene at five landscape window sizes and reports canvas/bounds/
  camera/margin geometry.
- tools/smoke_test.gd: 27 new layout-regression checks (framing
  contract, backdrop/frame, HUD placement/typography/touch-region
  exclusion, zone/help/binding content, touch visibility rules,
  restart/level-switch stability, landscape-canvas invariants);
  2 legacy camera checks updated to the corrected contract
  (old: unlimited limits for small maps).

Verification: probe at 1280x576 -> camera center (672, 360), margins
8% covered by the backdrop; 960x540 / 1280x720 / 1600x900 -> clamped,
no margin; 2340x1080 -> centered, 6.9% margins; restart -> identical
camera (no jump). Smoke suite 241/241 PASS (214 preserved, 27 added,
2 updated in place); import exit 0; 180-frame boot OK;
validate_project.sh OK. Task counts unchanged (26/30). Visual/
on-device appearance remains DEVICE-UNVERIFIED (headless geometry
evidence only).

## Phase 7 — Android Optimization (PARTIALLY COMPLETE — device verification outstanding)

- [x] P7-T1 Profiling pass; AI/physics tick throttling; node batching.
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
- [ ] P7-T2 Stable 60 FPS target on mid-range hardware (device evidence).
  OPEN and DEVICE-UNVERIFIED. Future verification plan (documented,
  not executed): mid-range Android device (e.g. Snapdragon 6/7-class,
  6 GB RAM), release or profiling build, representative scenarios
  (legacy steady, layout B doors, seeded, 8-enemy stress, active
  detection), frame-time distribution over >= 10 min sustained runs
  under thermal load, repeated comparable runs, input responsiveness
  while active. No headless result may mark this complete.

## Phase 8 — APK Packaging and Device Testing (PARTIALLY COMPLETE — host portion of P8-T1 and debug+release signing of P8-T2 verified; install and device criteria OPEN)

- [ ] P8-T1 Execute tools/setup_android.sh -> build_android.sh ->
      install_android.sh end to end.
      PARTIAL (host-verified to the install step): setup preflight
      exit 0 (all six prerequisites present), build_android.sh
      executed host-side and produced a signed debug APK; the
      install_android.sh step was deliberately NOT invoked (requires
      a physical device; out of scope by design for device-free
      pipelines). Remains open as written until an on-device install
      is performed.
- [x] P8-T2 Debug and release signing verification.
      Debug signing verified earlier (apksigner verify: v2 true, v3
      true, signer CN=Android Debug, SHA-256
      38be10fad45c9dce9a12929324ce5bb7c586ba523cbdd2107e0f7c22beee1676).
      Release signing verified 2026-10-24 (approved automated flow):
      a PKCS12 keystore with RSA-3072 key (alias shadow_protocol_upload,
      10000-day validity) was generated with CSPRNG credentials (never
      in argv, Git or project files) and used to build
      ShadowProtocol-v0.1.0-release.apk via environment-variable signing
      overrides; apksigner verify exit 0, schemes v2+v3 true, signer
      CN=Shadow Protocol Upload Key, SHA-256
      74ec3b4ec475f65517f0676b30d801f9fc557a5bb733dcabd70a5f016c574a0b
      (differs from the debug certificate). The private key never
      entered Git or any public file; the owner-only encrypted backup
      (AES-256-GCM + scrypt) was published and end-to-end verified
      (download, SHA-256, decrypt, keystore revalidation), and its
      recovery password was sent to the developer's verified private
      Telegram chat (approved Option 1). OWNER RETRIEVAL: NOT YET
      CONFIRMED — technical acceptance complete; awaiting the owner's
      confirmation that the archive and password were received and
      stored. Regression evidence same day: smoke 297/297,
      validate_project.sh exit 0 (21 host checks).
- [ ] P8-T3 On-device gameplay verification (REQUIRES a physical device;
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

## Counts

- Phases complete: 6 / 8 fully complete in their code-level scope
  (Phases 2-6 headless-verified); Phase 7 partially complete (P7-T1
  code-verified, P7-T2 device-unverified); Phase 8 partially complete
  at host level (setup+build+debug-signing verified; install step,
  release signing and device criteria open).
- Tasks complete: 27 / 30 (3 remaining: P7-T2, P8-T1, P8-T3; P8-T1
  remains a host-level partial pending the device install; P8-T2's
  technical acceptance is complete, owner backup retrieval NOT YET
  CONFIRMED).
- Unverified items: on-device/touchscreen behavior of all phases (protocol
  restriction), P7-T2 Android 60 FPS device criteria, Phase 8 device
  criteria (install + gameplay). Owner retrieval of the signing backup
  is delivered but not yet confirmed by the owner.
- Visual Quality Upgrade Iteration (2026-10-23): COMPLETE at code level;
  42 new presentation checks added, smoke total now 283/283. Not a
  numbered phase task - no change to the 26/30 task count.

## Historical verification references

- Phase 1: commit 66e3375; 14/14 smoke checks; pipeline exit 0 (2026-10-22).
- Phase 2: 36/36 smoke checks; import/boot/smoke/validate all exit 0 on the
  final tree (2026-10-22, Godot 4.7.2.stable.official.ed1daf0bf).
- Phase 3: 63/63 smoke checks (14 Phase 1 + 22 Phase 2 regression + 27 new
  Phase 3 behavioral checks); import/boot/validate all exit 0 on the final
  tree (2026-10-23, Godot 4.7.2.stable.official.ed1daf0bf).
- Phase 4: 116/116 smoke checks (63 Phase 1-3 regression + 53 new Phase 4
  generation/layout/door/zone/lifecycle checks); import/boot/validate all
  exit 0 on the final tree (2026-10-23, Godot 4.7.2.stable.official.ed1daf0bf).
- Phase 5: 157/157 smoke checks (116 Phase 1-4 regression + 41 new Phase 5
  mission-loop checks covering all 45 required scenarios); import/boot/
  validate all exit 0 on the final tree (2026-10-23, Godot
  4.7.2.stable.official.ed1daf0bf).
- Phase 6: 197/197 smoke checks (157 Phase 1-5 regression + 40 new
  camera/animation/HUD/feedback checks); import/boot/validate all exit 0
  on the final tree (2026-10-23, Godot 4.7.2.stable.official.ed1daf0bf).

## Audit Note (2026-10-23)

(Historical context: this earlier audit was performed while Phase 3 was
still the current focus; its focus statement below is a record of that
moment, not the present roadmap state. See the Phase 5 Integrity Audit
Note at the end of this file for the current status.)

Documentation-only integrity correction. Two derived totals were corrected
after an audit against the actual task list; no tasks, identifiers,
checkbox states or historical evidence were changed:

1. Phase 2 completion accounting: the Phase 2 report claimed "6/6 tasks
   verified (P2-T1..P2-T5 + regression/pipeline)". Phase 2 defines exactly
   five tasks; P2-T5 IS the regression-and-pipeline task, which was
   double-counted as a sixth item. Correct documented result: 5/5.
2. Overall task accounting: "Tasks complete: 11 / 24" was arithmetically
   wrong. Actual task inventory: Phase 1: 6, Phase 2: 5, Phase 3: 5,
   Phase 4: 3, Phase 5: 4, Phase 6: 2, Phase 7: 2, Phase 8: 3 = 30 tasks,
   11 complete, 19 remaining. Correct documented result: 11/30.

Verification evidence for all checked tasks is unchanged (see each task's
Evidence line and the Historical verification references section). Current
focus remains Phase 3. Device-level criteria remain unverified and open.

## Phase 5 Integrity Audit Note (2026-10-23, post-Phase-5 documentation audit)

Documentation-only integrity audit performed after the reported Phase 5
completion (commit 7819f79). Build Mode OFF, Git OFF; no gameplay code,
scenes, tests, engine configuration or dependencies were modified, and
nothing was staged, committed or pushed. Corrections made in this edit:

1. Phase 5 status heading: the heading stated "NOT STARTED" while all
   four P5 tasks (P5-T1..P5-T4) were checked with recorded evidence.
   Confirmed against this on-disk file; heading corrected to
   "COMPLETE at code level". No task IDs, names, order, checkboxes or
   historical evidence were changed.
2. Acceptance-criteria count: the original Phase 5 execution prompt
   defines exactly 24 distinct Definition-of-Done checklist items. The
   delivered Phase 5 report summarized them as "All 23 criteria met" —
   an incorrect summary count, not a missing criterion. All 24 items are
   substantively covered by the recorded evidence; the only imperfect
   item was #24 (roadmap consistency), impaired by the stale heading
   corrected in point 1. The delivered report's count has been corrected
   to 24.
3. Structural verification: 8 phases in original order, 30 unique task
   identifiers, per-phase completion 6/5/5/3/4/0/0/0 (23/30 overall,
   7 remaining), completed phases 5/8, current focus Phase 6 — all
   confirmed against the on-disk file. Test totals are consistent:
   157 total = 116 historical regression checks + 41 new Phase 5
   checks, covering the 45 requested behavioral scenarios (a test count
   is not the scenario count).

The Phase 5 verification results referenced by the tasks (157/157 smoke
checks, import/boot/validate exit 0, commit 7819f79) are HISTORICAL
evidence from the Phase 5 run; no Godot imports, smoke tests or builds
were executed during this documentation audit. Device-dependent
acceptance criteria remain open and unverified.

## Roadmap Update Verification Rule (added 2026-10-23)

After completing any phase, before reporting completion, the roadmap
update MUST be verified by reading the file back and confirming:
1. Every task in the phase has its expected checkbox state.
2. Each completed task has appropriate recorded evidence.
3. The phase heading matches the completed-task state (a checked phase
   must never remain headed "NOT STARTED").
4. Per-phase and overall counts were recalculated.
5. The current focus matches the next open phase.
This rule exists because the stale-heading defect recurred: Phase 5 was
corrected on 2026-10-23 but the same inconsistency reappeared for
Phase 6 when the task entries, counts and focus were updated without
touching the heading. No scripts or CI jobs are added - the rule is a
read-back checklist applied at update time.

## Phase 6 Integrity Audit Note (2026-10-23, post-Phase-6 documentation audit)

Documentation-only integrity audit following the reported Phase 6
completion (commit af912b8, pushed). Build Mode OFF, Git Commit/Push
Mode OFF: no gameplay code, scenes, tests, engine configuration or
dependencies were modified, and nothing was staged, committed or
pushed. No Godot commands were executed; all engine results cited are
HISTORICAL from the Phase 6 run. Corrections made in this edit:

1. Phase 6 status heading: stated "NOT STARTED" while both P6 tasks
   were checked with recorded evidence and the counts/focus had moved
   on (25/30, focus Phase 7). Confirmed against this on-disk file and
   corrected to "COMPLETE at code level". This is the SAME defect
   class as the Phase 5 heading corrected earlier the same day -
   the Phase 5 fix corrected one heading but added no update rule, so
   the defect recurred. The Roadmap Update Verification Rule above is
   the preventive measure. No task IDs, names, order, checkboxes or
   historical test evidence were changed.
2. P6-T2 evidence count: the entry summarized its evidence as "19
   Phase-6 checks". Recounted from the actual smoke-test section:
   the suite grew 157 -> 197 (+40) and the P6-T2-owned subset is 22
   checks (feedback/audio/haptic routing 12, detection meter 5, HUD
   layout 3, listener/staleness lifecycle 2); P6-T1 owns the other 18
   (camera 10, animation 8). The delivered Phase 6 report's category
   breakdown (10/7/12/4/4/3) contained the same faulty split and was
   corrected to 10/8/12/5/3/2; its TOTAL of 40 was correct. The
   roadmap's "19" was an incorrect summary, not evidence of failed
   tests: all 197 checks passed (historical result).
3. Acceptance criteria: the original Phase 6 Definition of Done
   contains exactly 27 criteria (10 P6-T1 + 17 P6-T2). Criterion 27
   (roadmap evidence and counts correct) was impaired at delivery by
   the stale heading and the wrong count; it is satisfied by this
   audit. All other criteria remain covered by the recorded
   code-level evidence. Device-dependent aspects (real-screen camera
   smoothness, touch feel, audible quality, hardware vibration,
   safe-area compliance, on-device FPS) remain explicitly UNVERIFIED
   under the device-free protocol.

## Visual Quality Upgrade Iteration (2026-10-23, COMPLETE at code level)

A presentation-only iteration requested after Phase 8: a cohesive NEON
NOIR / TACTICAL STEALTH visual pass over the existing game. No gameplay,
mission, stealth, collision or camera behavior was changed.

### Scope delivered (all host-verified via smoke section M)

- Player agent rig: body/head/visor/pack parts replacing the flat
  square; state tints (idle/crouch/sprint) applied via rig modulate;
  bob/crouch-scale mechanics untouched; collision stays 24x24.
- Enemy guard rig: cap/visor/indicator parts; FSM state colors plus an
  awareness glyph ("?" unconfirmed, "!" alert) driven only by the real
  state machine; patrol hides the glyph.
- Environment: floor panel seams; per-wall-run top highlight + bottom
  shadow; restricted-zone floor overlays (fill + border + real zone id
  label) for every zone; terminal and extraction ground glows.
- Doors: static doorframe, sliding panel with color-coded edge
  (red closed / green open), 0.12 s restrained slide tween; collision
  transition logic unchanged.
- Terminals: console rig (housing + status screen + LED); in-range
  highlight follows Main's existing nearest-target decision; completed
  state recolors screen + LED.
- Extraction: ExtractionBeacon replaces the flat marker (LOCKED dim /
  ACTIVE pulsing / DONE static, driven by the real extraction and
  mission state signals; the pulse is the only continuous animation and
  runs only while ACTIVE).
- HUD: panel + accent strip behind the existing 5-line HUD; meters
  restyled (caption 14 px, accent underline); Status unchanged.
- Touch: full action words (CROUCH/SPRINT/USE), cyan-tinted fills,
  pressed ring flash; hit geometry (42/52 px radii, zones) unchanged.
- Mission overlay: single reusable end-state panel (MISSION COMPLETE /
  MISSION FAILED + reason) shown only from the real MissionManager
  terminal states, with a functional RESTART button wired to
  restart_mission(); resets on restart and every level load.
- Warning layer: four thin screen edges whose alpha follows the real
  MissionManager detection ratio (calm = invisible; epsilon-gated
  updates, zero idle cost).
- Design system: scripts/palette.gd documents the shared palette.

### Bug found and fixed during the iteration

generate() freed old level children with queue_free() only, so a
re-generation on the same LevelRoot collided with the not-yet-freed
names and all named nodes (Extraction beacon, markers, roots) silently
lost their names on level switches/restarts. Fixed by detaching
children immediately (remove_child) while keeping deletion deferred.
Verified: probe showed named nodes surviving LAYOUT_B reload; beacon
updates now work across restarts.

### Evidence (2026-10-23, Godot 4.7.2.stable.official.ed1daf0bf)

- Smoke suite: 283/283 checks pass (241 historical regression checks
  all preserved + 42 new section M visual/presentation checks).
- Import, boot, smoke all exit 0 on the final tree.
- APK: ShadowProtocol-v0.2.0-debug.apk built and debug-signed with the
  project Android preset (apksigner reports "Signed").
- Device-dependent aspects (visual feel on a real screen, touch press
  feel, haptics, on-device FPS impact) remain UNVERIFIED under the
  device-free protocol, consistent with P7-T2/P8 device criteria.

## Post-Visual-Upgrade Acceptance Audit Note (2026-10-23)

Targeted acceptance audit of the Neon Noir upgrade (no new phase, no new
tasks; roadmap stays 26/30 with P7-T2, P8-T1, P8-T2, P8-T3 open and
device criteria unverified).

Confirmed defects found and fixed (minimal root-cause corrections):

1. Mission result overlay was off-center: the "Center" container is
   offset -PANEL_SIZE/2 from the center anchor AND the panel inside it
   repeated the same offset, shifting MISSION COMPLETE/FAILED panels
   210 px left and 75 px up of the viewport center (matches the
   supplied screenshot observation). Fix: panel sits at the Center
   origin (scripts/mission_overlay.gd). Runtime-measured after fix:
   panel center delta (0.0, 0.0) at 1280x720; inside safe bounds at
   960x540, 1280x576, 1280x720, 1600x900 and 2340x1080.
2. Contextual HUD feedback could appear alongside the mission result
   overlay ("Nothing to interact with here." while MISSION COMPLETE is
   open): _show_status had no end-state gate. Fix: contextual feedback
   is suppressed while the result overlay is showing; mission result
   lines are written before the overlay engages and contextual
   feedback resumes immediately after restart (scripts/main.gd).
   Interaction mechanics, zone notices and detection pings are
   untouched during active missions.

Regression evidence added: 14 new acceptance checks in smoke section M
(overlay centered + in-bounds for success and failure, stale message
replaced by mission status, contextual suppression during the end
state, restart reactivation, five-resolution centered/in-bounds loop).
Smoke total is now 297/297 PASS (241 historical + 42 presentation +
14 acceptance). Final-tree pipeline: import exit 0, boot (180 frames)
exit 0 with zero errors, smoke exit 0, tools/validate_project.sh exit 0
(GODOT_BIN=/tmp/godot).

Audit findings recorded without code change:
- Version audit: export_presets.cfg still declares version/name
  "0.1.0" (code 1); the v0.2.0 label exists only in the delivered APK
  FILENAME. The filename bump overstated project version metadata; no
  version value was modified during this audit.
- Typography: HUD font is a deliberate 16 px override at the 1280x720
  design viewport (stretch canvas_items/expand), unchanged; on-screen
  readability remains VISUALLY UNVERIFIED (device-free protocol).
- Git: commit 899159d (parent 7d3727c) contains only project sources
  (scenes/scripts/tools + report md); remote main matches it. The
  push was performed under the owner's standing delivery instruction;
  the acceptance-audit prompt itself specified Git mode OFF - recorded
  as a process discrepancy, no history rewritten.

## Phase 8 P8-T2 Note (2026-10-24, release signing verification)

P8-T2 remains OPEN. Debug signing fully verified on the final tree;
release signing is BLOCKED on a missing authorized prerequisite - no
release keystore exists (export preset keystore/release="", no
SHADOW_PROTOCOL_KEYSTORE credentials, no release keystore file in the
environment; only the standard debug keystore is present). Per the
phase protocol, no keystore was created and no placeholder credentials
were generated.

Verified evidence (fresh, this run):
- Rebuilt debug APK through the corrected pipeline:
  build/ShadowProtocol-v0.1.0-debug.apk (28 MB, exit 0; the exporter's
  adb child-process probe message is host-side and non-fatal).
- ZIP structure: 162 entries, testzip clean. aapt2 badging:
  com.shadowprotocol.game, versionCode 1, versionName 0.1.0, minSdk 24,
  arm64-v8a - consistent with export_presets.cfg. apksigner verify:
  exit 0, "Verifies", v2 + v3 schemes true, debug certificate.
- Godot pipeline: --import exit 0, --quit-after 180 exit 0, smoke
  297/297 PASS, tools/validate_project.sh exit 0.

Build-script defects found and fixed (tools/build_android.sh):
1. Artifact names hard-coded "v0.1.0"; now derived from the export
   preset's version/name (the hard-coded label was the class of defect
   behind the earlier v0.2.0 filename/version mismatch, which came
   from a caller-supplied output path).
2. Release signing still used --export-debug (would have produced a
   debug-signed artifact named -release); now uses --export-release.
3. Keystore credentials were injected through sed process arguments
   (visible in argv); now fed via stdin, preset restored from .bak on
   exit, and release builds fail fast without an existing keystore
   file / apksigner, with in-script apksigner signature verification.

New host-only regression checks: tools/test_build_android_host.sh
(9 PASS: bash -n syntax, version extraction + export_path agreement,
no hard-coded versions, correct export modes, no ADB/install commands,
stdin credential injection), now wired into tools/validate_project.sh
(step 5/5). Smoke total remains 297/297. Roadmap stays 26/30.

## Phase 8 P8-T2 Note (2026-10-24, secure keystore preparation)

P8-T2 remains OPEN - the release keystore must be generated by the
developer in their OWN interactive terminal (human-operation boundary);
no key was created in this remote environment and none will be.

Prepared and verified this run:
- tools/build_android.sh: release signing replaced the temporary
  export_presets.cfg mutation (which could persist the password on
  SIGKILL) with Godot's documented GODOT_ANDROID_KEYSTORE_RELEASE_*
  environment overrides; export_presets.cfg is never modified
  (verified byte-identical before/after a full debug build);
  --export-release retained; fail-fast on missing keystore (negative
  test: exit 1 before any build).
- tools/generate_release_keystore.sh (developer-run): TTY required,
  refuses to overwrite existing keystores, umask 077, 0700 dir,
  0600 file, keytool genkeypair RSA-3072/10000d PKCS12 with no
  password on the command line, non-secret validation printout,
  private-backup instructions.
- tools/build_release_local.sh (developer-run): interactive hidden
  password prompt (read -rs), credentials passed only through the
  environment of the Godot child process, cleared after the build.
- tools/verify_release_keystore.sh (developer-run): alias/PKCS12/
  certificate checks, rejects the debug certificate, permissions
  check; keytool prompts for the password locally.
- Host regression suite grown 9 -> 21 checks (syntax, version
  derivation, no cfg mutation, env-var signing, TTY guards, no
  password argv/literals, overwrite/umask guards, debug-cert
  rejection): 21 PASS / 0 FAIL.

Fresh verification: debug APK rebuilt (28 MB, zip 162 entries clean,
aapt2 badging com.shadowprotocol.game 0.1.0/1 arm64-v8a, apksigner
verify exit 0). Godot pipeline: import/boot/smoke 297/297 PASS,
tools/validate_project.sh exit 0 (incl. 21 host checks).
Roadmap remains 26/30; P7-T2, P8-T1, P8-T2, P8-T3 OPEN.
Next: developer generates the keystore locally and runs
tools/build_release_local.sh; then release APK signature audit
completes P8-T2.

## Phase 8 Complete GitHub Backup Note (2026-10-24, private delivery attempt)

Private signing delivery (Part A) is BLOCKED and, per the phase
protocol, NO keystore and NO password were generated: the environment's
only owner-restricted delivery facility (Base44 private storage +
expiring signed download URLs) was probed three times and failed
verification every time (HTTP 401 "token validation failed", from both
a sandboxed curl client and a real Chrome browser session). The
protocol forbids generating an irreplaceable private key before the
owner's secure receipt is verified. P8-T2 therefore remains OPEN.

Complete GitHub source backup (Part B) is DONE: README gained a
reproducible-development section (clone, toolchain, import, run,
tests, debug/release builds, keystore restore, signing configuration,
open roadmap items), roadmap.md itself is now committed per the
2026-10-24 complete-backup directive (superseding the earlier
external-only convention), all non-secret project files verified
tracked (70 files; assets/ is empty placeholders - the game is fully
procedural), history scanned clean of secrets, and a fresh-clone
reproducibility test (clone + import + smoke) was executed
successfully. P8-T2, P7-T2, P8-T1, P8-T3 remain OPEN (26/30).

## Phase 8 Private-Delivery Diagnostic Note (2026-10-24)

P8-T2 remains OPEN; no keystore, password or release APK was created,
per the phase protocol's stop rule. The blocked signed-URL delivery was
diagnosed with non-secret evidence: the generated download tokens carry
an issuer/subject application identity (urn:app:588d9e23...) that does
not match the object-owning application in the file path
(6a23f0e31a5238e6a0f12e8b), audience urn:service:file.download, 900s
validity - the media service rejects the cross-application token with
HTTP 401 "token validation failed" from every client tested. This is a
platform-side token-configuration defect; authentication was not, and
must not be, disabled.

Alternative owner-only delivery mechanisms actually inspected and ruled
out this run: authenticated API file routes (private objects return
404 file_not_found even with a valid service token; public objects do
serve), all OAuth connectors (none authorized), recipient public-key
E2E delivery (no GPG/SSH keys published on the developer's GitHub
account), agent secret storage (owner-viewable editor Secrets tab
exists, but this agent has no set_secrets capability), agent API docs
endpoints (app not found without the editor-provided base), and
backend-function retrieval (no owner-accessible authenticated
invocation surface verifiable from this environment). Telegram, GitHub
and public storage remain excluded for signing secrets per the phase
protocol. Key generation stays withheld until a verified owner-only
channel exists; the one-time owner decision that unblocks it is
documented in the accompanying report. Roadmap remains 26/30.

## Phase 8 P8-T2 Release Signing Completion Note (2026-10-24)

The developer approved Option 1 (encrypted public backup + Telegram
password delivery). Execution: Telegram channel preflight (platform
bot integration verified; the environment's raw Bot API token is
invalid - HTTP 401 twice - and was not used; direct delivery goes
through the agent's connected Telegram bot to the developer's
verified private chat). Public-delivery preflight passed with a
harmless AES-256-GCM/scrypt sample (upload/download SHA-256 match,
wrong-password and tamper cases both rejected). A PKCS12 keystore
(RSA-3072, alias shadow_protocol_upload, 10000-day validity,
certificate SHA-256
74ec3b4ec475f65517f0676b30d801f9fc557a5bb733dcabd70a5f016c574a0b)
was generated with CSPRNG passwords outside the repository
(restrictive permissions, no secrets in argv/Git/files/logs).
The recovery package (keystore + credential record + restore
instructions + SHA-256 manifest + public certificate) was encrypted
as an SPBK1 container (AES-256-GCM, scrypt n=2^15 r=8 p=1, random
salt, unique nonce, independent 256-bit archive password), published
through the normal HTTPS route, and verified end-to-end (remote
download, SHA-256 ff29bc5d..., decrypt, keystore revalidation with
its own password, wrong-password/tamper rejection). The release APK
was built through the environment-variable signing flow and verified
(apksigner exit 0, v2+v3 true, fingerprint identical to the generated
key, distinct from the debug certificate). Final-tree regression:
smoke 297/297, validate_project.sh exit 0 (21 host checks). Roadmap
27/30. Owner retrieval of the encrypted backup and password:
DELIVERED AND CONFIRMED (2026-10-24, developer message with Windows 11
PowerShell evidence): downloaded shadow-protocol-signing-backup-v1.spbk,
verified SPBK1 container parameters (scrypt n=32768 r=8 p=1,
AES-256-GCM), decrypted with the separately received recovery password
(7975 bytes recovered), ciphertext SHA-256 matched
ff29bc5dbbd564ca288d773c1fa5dbe555baae8f14270bd8d85094ee71792638,
expected member listing confirmed (keystore, public certificates,
fingerprint file, credential record, restore instructions, manifest),
and the temporary decrypted file was removed after inspection. Limits:
this does NOT establish a separate offsite backup, an independent
Windows keytool verification of the inner private-key entry, or any
Android runtime behavior. Telegram delivery was an ordinary cloud
message (not E2EE Secret Chat); the encrypted archive is publicly
reachable but only the archive password holder can decrypt. No secret
values appear in this record.
## Phase 7/8 Device Handoff Note (2026-10-24, host-side preparation)

P7-T2, P8-T1 and P8-T3 remain OPEN and DEVICE-UNVERIFIED; this
iteration completed every practical device-free preparation for them.

- docs/ANDROID_DEVICE_ACCEPTANCE.md added: P7-T2 60 FPS test plan over
  the nine verified benchmark scenarios (A_legacy_steady through
  I_door_active, IDs checked against tools/benchmark.gd), P8-T1 install
  checklist with the debug-certificate upgrade-incompatibility warning,
  and the P8-T3 gameplay matrix (18 implemented mechanics plus two
  documented NOT-IMPLEMENTED items: main menu and pause/persistence).
- tools/verify_release_apk_host.sh added: standalone host-only release
  APK verifier (ZIP integrity, package/version metadata, v2+v3
  signature, release fingerprint match, debug-certificate rejection,
  argument validation; no secrets, no absolute paths, no ADB).
  Result on build/ShadowProtocol-v0.1.0-release.apk: 5 PASS / 0 FAIL;
  correctly rejects the debug-signed APK.
- Host regression checks 21 -> 26 (verifier syntax, path portability,
  release acceptance, debug rejection, argument validation), all
  passing; smoke 297/297; import/boot/validate exit 0;
  setup_android.sh --preflight exit 0 with all six prerequisites
  (java/godot on PATH).
- Fresh release artifact audit (2026-10-24): ZIP 153 entries clean,
  package com.shadowprotocol.game 0.1.0/1 arm64-v8a, release certificate
  74ec3b4ec475f65517f0676b30d801f9fc557a5bb733dcabd70a5f016c574a0b,
  debug certificate absent, APK SHA-256
  fc40011c4182e2b0ce8e1359993f9a5ed763dd7d7929885303f5c5a056329a3b.

Counts remain 27/30. P7-T2, P8-T1 and P8-T3 can only close with real
device evidence collected per the handoff document.
