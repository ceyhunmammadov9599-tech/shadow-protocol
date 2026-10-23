# Shadow Protocol

A top-down tactical stealth-action game for Android, inspired by the gameplay
philosophy of Splinter Cell. Built entirely from the Linux command line with
Godot 4.7 and GDScript - no Godot editor required for development or builds.

You are a covert operative. Infiltrate guarded facilities, use light and
shadow, avoid patrols, complete objectives and extract undetected.

## Status

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
   export templates, Android SDK cmdline-tools, debug keystore):

       tools/setup_android.sh

3. Build the APK (debug signing by default; release signing only through
   SHADOW_PROTOCOL_KEYSTORE / SHADOW_PROTOCOL_KEYSTORE_USER /
   SHADOW_PROTOCOL_KEYSTORE_PASSWORD environment variables - secrets are
   never committed):

       tools/build_android.sh

4. Install and launch on a connected device:

       tools/install_android.sh

## Desktop test run

    godot --path . 

Controls: WASD move, C crouch, Shift sprint, E interact.

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
