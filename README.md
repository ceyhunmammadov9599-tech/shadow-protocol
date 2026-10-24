# Shadow Protocol

A top-down tactical stealth-action game for Android, inspired by the gameplay
philosophy of Splinter Cell. Built entirely from the Linux command line with
Godot 4.7 and GDScript - no Godot editor required for development or builds.

You are a covert operative. Infiltrate guarded facilities, use light and
shadow, avoid patrols, complete objectives and extract undetected.

## Status

Phase 7 (Android optimization) - P7-T1 complete at headless-verification
level (profiling pass + targeted, behavior-preserving optimizations);
P7-T2 (stable 60 FPS on mid-range hardware) remains OPEN pending
real-device evidence:

- Reproducible device-free benchmark: tools/benchmark.tscn runs nine
  scenario IDs (legacy/layout B/layout C steady, seeded, 8-enemy
  stress, active detection, movement, restart cycle, door) with
  warmup, fixed measured windows, 3 repetitions and deterministic
  operation counters; host wall-clock is reported separately and
  never claimed as Android performance (headless renderer metrics are
  unavailable by design)
- HUD text is rebuilt only when a tracked value changes (zero
  steady-state rebuilds vs one per idle frame before)
- Player visibility pushes/emits only on value change; the visibility
  meter stays exact to StealthSystem.compute_visibility
- FeedbackManager idle processing is disabled while no feedback
  cooldown is live
- ALERT pursuit reuses the same-tick vision result (no duplicate
  raycast per decision tick)
- Evidence-based no-change decisions kept the already-correct parts
  intact: AI decision accumulator throttling, distance->FOV->raycast
  vision gating, spawn-time patrol BFS, merged wall runs, static
  lights without _process, and the per-frame genuinely-seen mission
  loop (changing its cadence would alter detection-timing semantics)
- Regression suite: 214/214 checks pass (197 historical + 17 new
  Phase-7 optimization-correctness checks), headless, device-free

Previous milestone - Phase 6 (mobile gameplay polish):

- Camera: built-in Camera2D position smoothing (configurable speed),
  per-axis map-bounds limits only when the map is viewport-sized or
  larger (small maps keep valid defaults), reset_smoothing() on every
  level load/restart so the view never starts away from the player;
  camera is the player's child (no stale references)
- Visible movement states IDLE/WALK/SPRINT/CROUCH from the real
  crouch/velocity/sprint values (one signal per transition, no
  near-zero flicker); procedural bob/tint/scale presentation with no
  collision or speed changes; shared keyboard/touch animation path
- Responsive HUD: compact anchored mission HUD, visibility meter
  (exposure) and detection meter (confirmed-contact risk) kept
  DISTINCT; suspicion is a subtle hint, never an alarm; touch
  reserved regions (joystick, buttons) are formalized and asserted
  clear at three representative landscape sizes
- FeedbackManager: five code-synthesized audio tones (terminal, door,
  warning with 2 s cooldown, success, failure), single playback owner
  per event, mute switch; haptics separated from hardware with config
  + cooldown guards (vibration only attempted on real mobile
  platforms, never headless)

Phase 5 (mission gameplay) - complete at headless-verification level:

- Interactive terminals (scripts/terminal.gd): spawned from grid
  markers with deterministic ids; context-sensitive INTERACT via the
  existing keyboard action and touchscreen contract; nearest eligible
  target, physics line-of-sight (walls and closed doors block); one
  press = one target; duplicate completion impossible
- Mission manager (scripts/mission_manager.gd): READY/ACTIVE/
  SUCCEEDED/FAILED with final-state guards; objectives tracked by
  stable id across any layout; extraction locked until all objectives
  complete, success only inside the extraction region; invalid
  missions rejected, never falsely successful
- Failure rule: sustained genuine visual contact (enemy can_see_
  player) fills a configurable detection grace timer that fully resets
  when contact ends; restricted zones double the pressure; suspicion
  and noise never fail the mission; multiple enemies never multiply
  the rate
- Door interaction: INTERACT opens nearby closed doors (immediate
  collision + vision + navigation update); restricted-zone entry/exit
  feedback; mission restart (R) resets everything with no leaks

Phase 4 (procedural level generation) - complete at headless-verification
level:

- LevelCatalog: central tile encoding (0 floor, 1 lit, 2 wall, 3 terminal,
  4 spawn, 5 enemy, 6 extraction, 7 door) and three distinct authored
  layouts (legacy regression fixture, layout B, layout C)
- Doors with real collision: closed doors block movement and enemy vision
  raycasts, open doors permit both; deterministic state transitions;
  navigation queries update live with door state
- Restricted zones: stable ids + deterministic rects, queryable by world
  position; overlapping definitions rejected
- Seeded procedural generation (rooms + corridors + doors + zones + lamps):
  same seed reproduces the same level, bounded attempts with rejection
  reasons and a validated fallback, BFS reachability validation
- Main scene loads any level descriptor with full lifecycle cleanup
  (no duplicate enemies, leaked lights, stale doors or subscriptions)

Phase 3 (enemy artificial intelligence) - complete at headless-verification
level:

- Enemy guard (CharacterBody2D, scenes/enemy.tscn) with a six-state AI:
  PATROL, SUSPICIOUS, INVESTIGATING, ALERT, SEARCHING, RETURNING -
  explicit transitions and a state_changed signal
- Visual detection: vision range + FOV dot-product + physics raycast
  wall obstruction; detection strength derived from the Phase 2 player
  visibility coefficient (distance-scaled, close-range floor)
- Suspicion accumulation and decay with configurable thresholds; enemies
  chase the live player only while visible and anchor to the last known
  position otherwise; bounded search; safe return to patrol
- Noise reaction via StealthSystem.noise_emitted with documented
  priority rules (visual contact wins; duplicates do not restart
  investigations); subscriptions cleaned up on removal
- Throttled AI decisions (configurable interval) with unthrottled
  movement; multiple enemies keep independent state
- Grid value 5 spawns enemies (two in the test level) with deterministic
  wall-aware patrol routes; DETECTED status feedback

Phase 2 (stealth and visibility) - complete at headless-verification level:

- Dynamic LightSource component (extends PointLight2D): one parameter set
  (position, radius, intensity, enabled) drives both rendered light and
  the gameplay illumination model; static and moving (ping-pong) sources
- Advanced visibility model: illumination = max(static grid layer,
  dynamic light layer with quadratic falloff), crouch factor, single
  motion boost, clamped 0..1
- Noise propagation foundation: NoiseEvent contract + central
  StealthSystem.publish_noise() dispatch with same-frame dedup - Phase 3
  enemy AI subscribes without touching the player controller
- Gameplay visibility meter (top-center, procedurally drawn, smoothed,
  low/medium/high bands) bound to live stealth-system values

Phase 1 (functional project foundation) - complete:

- Grid-generated collision test level (16 x 28) with walls, illuminated
  floor zones, terminal, extraction point, player and enemy spawn data
- CharacterBody2D player controller: analog/keyboard movement,
  acceleration and friction, crouch, sprint, noise and visibility
  interfaces
- Deterministic grid-based illumination model (StealthSystem autoload)
- Multi-touch controls: floating virtual joystick (left half of the
  screen) plus CROUCH / SPRINT / INTERACT buttons (right side), with
  pointer-index tracking so simultaneous input never interferes
- Keyboard fallback (WASD, C, Shift, E) for desktop and headless testing
- Debug HUD: speed, posture, visibility, noise radius
- Android export preset (arm64) and CLI build pipeline

Planned phases (following the master development plan): stealth and
visibility depth, enemy AI (patrol/suspicion/investigate/search states),
procedural level variety, mission gameplay, mobile polish, Android
optimization, APK packaging and device testing.

## Project layout

    project.godot          engine config, input map, mobile renderer
    export_presets.cfg     Android export preset (debug signing default)
    scenes/main.tscn       game root: level, player, UI
    scenes/player.tscn     player scene
    scripts/main.gd        level lifecycle, wiring, HUD
    scripts/player.gd      movement, crouch/sprint, stealth interfaces
    scripts/mobile_controls.gd  multi-touch joystick + action buttons
    scripts/level_generator.gd  grid -> walls, floors, markers, metadata
    scripts/stealth_system.gd   autoload: visibility + noise model
    tools/                 CLI pipeline (validate, setup, build, install)
    build/                 export output (git-ignored)

## CLI workflow

All commands are run from the repository root.

1. Validate the project headless (no editor, no display). This imports
   resources, boots the main scene, simulates frames and runs the
   movement/stealth smoke test:

       GODOT_BIN=/path/to/godot tools/validate_project.sh

2. Prepare the Android toolchain (verifies Java 17+, Godot 4.7.2,
   export templates 4.7.2.stable, Android SDK (cmdline-tools or a
   directly provisioned build-tools/platforms layout), build-tools
   aapt2+apksigner, debug keystore). Installs nothing; add
   --preflight for a machine-usable check that exits 0 only when
   every prerequisite is present:

       tools/setup_android.sh
       tools/setup_android.sh --preflight

3. Build the APK (debug signing by default; release signing only through
   SHADOW_PROTOCOL_KEYSTORE / SHADOW_PROTOCOL_KEYSTORE_USER /
   SHADOW_PROTOCOL_KEYSTORE_PASSWORD environment variables - secrets are
   never committed). Requires ANDROID_SDK_ROOT (or ~/android-sdk) with
   build-tools 34.0.0, platform android-34, platform-tools and a JDK 17+
   (JAVA_HOME); the export runs under a 15-minute bound:

       tools/build_android.sh

4. Install and launch on a connected device (requires a physical Android
   device via ADB; never part of device-free pipelines):

       tools/install_android.sh

## Desktop test run

    godot --path . 

Controls: WASD move, C crouch, Shift sprint, E interact.

Touch-overlay debugging: the on-screen controls appear only on real
touchscreens/Android; set `shadow_protocol/touch_debug=true` in
project.godot to force them visible on desktop for layout testing.

## Engineering notes

- All scenes are text .tscn files and can be reviewed in any diff tool.
- Walls are merged into horizontal runs (one StaticBody2D per run) to
  keep the node count low.
- The illumination model is a deterministic gameplay model based on lit
  grid cells, crouch posture and motion - deliberately not a physically
  based light simulation. Phase 2 extends it with dynamic light sources.
- Enemy AI, procedural level variety and mission logic are intentionally
  out of scope until Phases 3-5; the interfaces (noise_emitted,
  visibility, enemy spawn points, terminals) are already in place.

## Reproducible development environment

Clone and continue development on any computer:

1. Clone: `git clone https://github.com/ceyhunmammadov9599-tech/shadow-protocol.git`
2. Requirements: Godot 4.7.2 (stable), JDK 17+, Android SDK with
   build-tools 34+ (aapt2, apksigner), Linux/Bash.
3. Open/import: `godot --headless --path . --import` (regenerates the
   .godot cache; it is not committed).
4. Run the game: open the project in the Godot editor and press F5, or
   `godot --path .` from the project root.
5. Smoke tests: `godot --headless --path . res://tools/smoke_test.tscn`
   (expects "SMOKE TEST: all checks passed", 297 checks).
6. Full validation: `bash tools/validate_project.sh` (import + boot +
   smoke + Android build host checks; needs GODOT_BIN and
   ANDROID_SDK_ROOT set if not on PATH).
7. Debug APK: `bash tools/build_android.sh` (expects Godot 4.7.2 and
   Android build-tools; produces build/ShadowProtocol-v0.1.0-debug.apk).
8. Release signing: the signing keystore is deliberately NOT in this
   repository. Restore it from your separate private backup (created
   via tools/generate_release_keystore.sh), then run
   `bash tools/build_release_local.sh`, which prompts for the password
   and passes it only through the Godot child-process environment
   (GODOT_ANDROID_KEYSTORE_RELEASE_*). Never place passwords in
   export_presets.cfg or any committed file.
9. Verify a release APK: `apksigner verify --print-certs <apk>` and
   compare the SHA-256 fingerprint with your keystore certificate.
   Never replace an existing keystore silently (published-app
   updates would become uninstallable).
10. Continue development: add features, run the smoke suite, and
    update roadmap.md evidence as tasks complete. Roadmap items that
    remain OPEN: P7-T2 (60 FPS on mid-range hardware), P8-T1 (device
    installation), P8-T3 (on-device gameplay verification). These
    require a physical Android device and are therefore not claimed
    complete by any host-side test.
