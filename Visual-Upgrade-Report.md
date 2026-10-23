# Shadow Protocol — Visual Quality Upgrade Report (2026-10-23)

## Objective

A presentation-only visual pass (NEON NOIR / TACTICAL STEALTH) over the
fully tested Phase 1-8 game: player/enemy/environment visuals, doors,
terminals, extraction, HUD, touch controls, mission end-state overlay,
detection feedback. Gameplay, mission, stealth, collision and camera
behavior untouched.

## Design system

`scripts/palette.gd` documents the shared palette (environment, actors,
semantics, interface, spacing/motion). Typography stays on the bundled
fallback font: title 26 px (overlay), body 14-16 px, tactical captions
14 px, all uppercase labels.

## What changed, by area

1. Player — four-part agent rig (Pack/Body/Head/Visor) replaces the flat
   square; state tint via rig `modulate` (idle/crouch/sprint), existing
   bob and crouch-scale mechanics preserved; collision 24x24 unchanged.
2. Enemy — guard rig (Body/Cap/Visor) + state colors; awareness glyph
   above the guard: "?" for suspicion/investigation/search, "!" for
   alert, nothing on patrol/returning; visor goes hot red only on alert.
3. Environment — floor panel seams (single Line2D); wall-run top
   highlights + bottom shadows; restricted-zone overlays (translucent
   fill + border + real zone-id label); terminal/extraction ground glows.
4. Doors — static doorframe; sliding panel retracting to 12% in 0.12 s;
   edge strip red (closed) / green (open); collision logic unchanged.
5. Terminals — console rig (Housing/Screen/LED); in-range highlight
   driven by Main's existing nearest-target throttle; completion
   recolors screen + LED; duplicate completion still rejected.
6. Extraction — ExtractionBeacon (LOCKED dim / ACTIVE slow pulse /
   DONE static) driven by the real extraction-availability and
   mission-state signals; pulse runs only while ACTIVE (idle cost 0).
7. HUD — panel + cyan accent strip behind the existing 5-line HUD;
   meters restyled; all historical HUD contracts preserved.
8. Touch — full action words (CROUCH/SPRINT/USE), cyan-tinted fills,
   pressed ring flash; radii/hit zones unchanged (42/52 px).
9. Mission overlay — single reusable end-state panel with title,
   reason/subtitle and a functional RESTART button (wired to
   restart_mission); shown only from real MissionManager terminal
   states; resets on restart and every level load; no duplicate
   instances; no nonfunctional continue button.
10. Detection warning — four screen-edge rects whose alpha follows the
    real MissionManager detection ratio; calm = fully invisible;
    epsilon-gated updates.

## Bug found and fixed

`generate()` freed old level children with deferred `queue_free()` only;
re-generating on the same LevelRoot collided with not-yet-freed names, so
named nodes (Extraction beacon, markers, roots) silently lost their names
across level switches/restarts. Fixed: detach immediately
(`remove_child`) + keep deletion deferred. Probe-verified: named nodes
survive a LAYOUT_B reload; beacon state updates work across restarts.

## Verification (Godot 4.7.2.stable.official.ed1daf0bf, headless)

- Import: exit 0. Boot: exit 0, level generates, no script errors.
- Smoke suite: 283/283 PASS = all 241 historical regression checks
  preserved + 42 new section M presentation checks (player rig and
  tints, enemy state/glyph mapping, seams/wall edges/zone overlays,
  door visuals vs collision state, terminal states + highlight,
  beacon lock/activate, warning-layer mapping + live integration,
  HUD panel, touch labels/geometry/press signal, overlay lifecycle
  from the real state handlers incl. restart resets, fixture teardown).
- Perf posture: presentation changes are procedural draws; the only new
  continuous animation is the ACTIVE beacon pulse (one node, gated);
  warning layer updates are epsilon-gated; HUD rebuild throttling and
  bench counters unchanged. On-device FPS remains P7-T2 (open).

## Build

ShadowProtocol-v0.2.0-debug.apk built and debug-signed via the project
Android preset (apksigner: "Signed"). Device install/gameplay and
release signing remain open Phase 8 device criteria.

## Status

Visual upgrade iteration COMPLETE at code level. Next open work: device
verification (P7-T2 FPS criteria, Phase 8 install/gameplay/release
signing).
