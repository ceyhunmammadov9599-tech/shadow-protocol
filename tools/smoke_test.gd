extends Node
## Shadow Protocol - headless smoke test scene (Phases 1-2).
##
## Runs inside the real engine loop (physics spaces active, autoloads
## loaded) and verifies acceptance criteria testable without a device.
## Run with:
##   godot --headless --path . res://tools/smoke_test.tscn
## Exit code 0 = all checks passed.

const TOL: float = 0.001

var failures: int = 0
var _noise_events: Array = []


func _ready() -> void:
	# ================= A. Player movement (Phase 1 regression) =================
	var player: CharacterBody2D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	add_child(player)
	player.position = Vector2(240, 240)
	await _frames(3)  # let physics spaces register

	Input.action_press("move_right")
	await _frames(60)
	var walk_speed: float = player.velocity.length()
	_check(walk_speed > 200.0 and walk_speed <= 240.0, "walk speed in (200, 240], got %.1f" % walk_speed)
	Input.action_release("move_right")

	Input.action_press("crouch")
	Input.action_press("move_right")
	await _frames(120)
	_check(player.crouching, "crouching flag set")
	var crouch_speed: float = player.velocity.length()
	_check(crouch_speed > 90.0 and crouch_speed <= 110.0, "crouch speed in (90, 110], got %.1f" % crouch_speed)
	Input.action_release("move_right")
	Input.action_release("crouch")

	await _frames(120)
	_check(player.velocity.length() < 1.0, "stops after friction, got %.2f" % player.velocity.length())

	Input.action_press("move_right")
	Input.action_press("sprint")
	await _frames(120)
	_check(player.sprinting and player.velocity.length() > 240.0,
		"sprint exceeds walk speed, got %.1f" % player.velocity.length())
	Input.action_release("move_right")
	Input.action_release("sprint")

	# ================= B. Touch joystick (Phase 1 regression) =================
	var touch: Control = load("res://scripts/mobile_controls.gd").new()
	add_child(touch)
	touch._joystick_index = 0
	touch._joystick_origin = Vector2(200, 200)
	touch._update_joystick(Vector2(210, 200))  # 10px: below dead zone
	_check(touch.get_movement_vector() == Vector2.ZERO, "dead zone zeroes tiny drags")
	touch._update_joystick(Vector2(310, 200))  # 110px: full saturation
	var full: Vector2 = touch.get_movement_vector()
	_check(absf(full.x - 1.0) < TOL and absf(full.y) < TOL,
		"full drag saturates to unit vector, got %s" % full)
	touch._update_joystick(Vector2(255, 200))  # half range: partial intensity
	var half: Vector2 = touch.get_movement_vector()
	_check(half.x > 0.2 and half.x < 0.9, "mid drag gives partial intensity, got %s" % half)
	touch._handle_release(0)
	_check(touch.get_movement_vector() == Vector2.ZERO, "release returns to neutral")

	player.queue_free()
	touch.queue_free()

	# ================= C. Stealth visibility model (Phases 1-2) =================
	var stealth: Node = get_node("/root/StealthSystem")
	stealth.configure({Vector2i(5, 5): true}, 48.0, Vector2.ZERO)

	# Static grid layer (Phase 1 behavior preserved).
	var lit_vis: float = stealth.compute_visibility(Vector2(250, 250), false, 0.0)
	var shadow_vis: float = stealth.compute_visibility(Vector2(2500, 900), false, 0.0)
	var crouch_vis: float = stealth.compute_visibility(Vector2(250, 250), true, 0.0)
	var shadow_moving: float = stealth.compute_visibility(Vector2(2500, 900), false, 1.0)
	_check(lit_vis > shadow_vis, "lit cell more visible than shadow (%.2f vs %.2f)" % [lit_vis, shadow_vis])
	_check(crouch_vis < lit_vis, "crouching reduces visibility (%.2f vs %.2f)" % [crouch_vis, lit_vis])
	_check(shadow_moving > shadow_vis, "motion increases visibility in shadow (%.2f vs %.2f)" % [shadow_moving, shadow_vis])
	_check(stealth.noise_radius(true, 0.0) < stealth.noise_radius(false, 1.0, false),
		"crouch quieter than running")
	_check(stealth.noise_radius(false, 1.0, true) > stealth.noise_radius(false, 1.0, false),
		"sprint loudest")

	# Dynamic lights: lifecycle.
	var lights_before: int = stealth.light_count()
	var lamp := LightSource.new()
	lamp.position = Vector2(500, 500)
	lamp.light_radius = 160.0
	lamp.light_intensity = 0.8
	add_child(lamp)
	await _frames(1)
	_check(stealth.light_count() == lights_before + 1, "light registers with StealthSystem")

	# Dynamic light contribution raises visibility over the grid-only value.
	var lit_point: Vector2 = Vector2(560, 500)   # in shadow cell, inside lamp radius
	var with_lamp: float = stealth.compute_visibility(lit_point, false, 0.0)
	var grid_only: float = stealth.compute_visibility(Vector2(2500, 900), false, 0.0)
	_check(with_lamp > grid_only + TOL, "dynamic light increases visibility (%.2f vs %.2f)" % [with_lamp, grid_only])

	# Distance falloff: closer is brighter, beyond radius is zero.
	var near: float = stealth.dynamic_light_at(Vector2(520, 500))
	var mid: float = stealth.dynamic_light_at(Vector2(580, 500))
	var far: float = stealth.dynamic_light_at(Vector2(659, 500))
	var outside: float = stealth.dynamic_light_at(Vector2(700, 500))
	_check(near > mid and mid > far, "distance reduces contribution predictably (%.3f > %.3f > %.3f)" % [near, mid, far])
	_check(absf(outside) < TOL, "beyond radius contributes zero, got %.4f" % outside)

	# Disabling the light removes its contribution.
	lamp.set_light_enabled(false)
	var disabled_vis: float = stealth.compute_visibility(lit_point, false, 0.0)
	_check(absf(disabled_vis - grid_only) < TOL,
		"disabling light reduces visibility back to grid-only (%.2f vs %.2f)" % [disabled_vis, grid_only])
	lamp.set_light_enabled(true)

	# Crouching reduces visibility under a dynamic light.
	var lamp_crouch: float = stealth.compute_visibility(lit_point, true, 0.0)
	_check(lamp_crouch < with_lamp - TOL, "crouching reduces visibility under dynamic light (%.2f vs %.2f)" % [lamp_crouch, with_lamp])

	# Multiple lights combine additively (sum), predictably.
	var lamp2 := LightSource.new()
	lamp2.position = Vector2(500, 500)
	lamp2.light_radius = 160.0
	lamp2.light_intensity = 0.3
	add_child(lamp2)
	await _frames(1)
	var pair_total: float = stealth.dynamic_light_at(lit_point)
	lamp2.set_light_enabled(false)
	var single_total: float = stealth.dynamic_light_at(lit_point)
	_check(pair_total > single_total + TOL,
		"second light adds its contribution (%.3f vs %.3f)" % [pair_total, single_total])
	lamp2.set_light_enabled(true)

	# Overlapping strong lights clamp illumination at exactly 1.0.
	for i in range(5):
		var strong := LightSource.new()
		strong.position = Vector2(500, 500)
		strong.light_radius = 300.0
		strong.light_intensity = 0.9
		add_child(strong)
	await _frames(1)
	var clamped: float = stealth.dynamic_light_at(lit_point)
	var clamped_vis: float = stealth.compute_visibility(lit_point, false, 0.0)
	_check(absf(clamped - 1.0) < TOL, "illumination clamps at 1.0, got %.4f" % clamped)
	_check(absf(clamped_vis - 1.0) < TOL, "visibility stays normalized (1.0), got %.4f" % clamped_vis)

	# Removing lights unregisters them (lifecycle teardown).
	for child: Node in get_children():
		if child is LightSource:
			child.queue_free()
	await _frames(2)
	_check(stealth.light_count() == 0, "all lights unregister on removal, got %d" % stealth.light_count())

	# ================= D. Noise propagation foundation (Phase 2) =================
	stealth.noise_emitted.connect(_on_noise_event)
	_noise_events.clear()
	stealth.publish_noise(Vector2(100, 200), 220.0, &"player", &"walk")
	stealth.publish_noise(Vector2(100, 200), 220.0, &"player", &"walk")  # same frame, same source
	stealth.publish_noise(Vector2(300, 400), 90.0, &"camera", &"still")  # different source
	await _frames(1)
	_check(_noise_events.size() == 2,
		"same-frame duplicate dropped, different source kept (got %d events)" % _noise_events.size())
	if _noise_events.size() >= 2:
		var ev0: NoiseEvent = _noise_events[0]
		var ev1: NoiseEvent = _noise_events[1]
		_check(ev0.position == Vector2(100, 200) and absf(ev0.radius - 220.0) < TOL
			and ev0.source_id == &"player" and ev0.movement_state == &"walk",
			"noise event carries correct position/radius/source/state")
		_check(ev1.source_id == &"camera", "second event keeps its own source id")
	await _frames(2)  # new frame: dedup window passes
	_noise_events.clear()
	stealth.publish_noise(Vector2(10, 10), 90.0, &"player", &"crouch")
	stealth.publish_noise(Vector2(10, 10), 320.0, &"player", &"sprint")
	_check(_noise_events.size() == 1, "per-source dedup also applies to state changes")
	stealth.noise_emitted.disconnect(_on_noise_event)

	# ================= E. Main scene integration (Phase 2 wiring) =================
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _frames(10)  # async level load completes, lights spawn, meter driven
	_check(stealth.light_count() == 5, "main scene registers 4 static + 1 moving light, got %d" % stealth.light_count())
	# Phase 3 grid integration (P3-T5).
	var wall_bodies: int = main.get_node("LevelRoot/Walls").get_child_count()
	_check(wall_bodies >= 20, "grid value 2 produces real wall collision bodies (>= 20), got %d" % wall_bodies)
	var enemies_main: Array = main.enemies
	_check(enemies_main.size() == 2, "grid value 5 spawns two enemies, got %d" % enemies_main.size())
	if enemies_main.size() == 2:
		var exp_spawns: Array[Vector2] = [Vector2(696.0, 312.0), Vector2(216.0, 600.0)]
		var positions_ok: bool = true
		for i in range(2):
			if enemies_main[i].global_position.distance_to(exp_spawns[i]) > 8.0:
				positions_ok = false
		_check(positions_ok, "enemy positions match grid cell centers (not inside walls)")
		var patrolling: bool = enemies_main[0].state == &"patrol" and enemies_main[1].state == &"patrol"
		_check(patrolling, "spawned enemies start in PATROL")

	var main_player: CharacterBody2D = main.get_node("Player")
	var meter: Control = main.get_node("UI/VisibilityMeter")
	var expected: float = stealth.compute_visibility(
		main_player.global_position, main_player.crouching, main_player.speed_ratio)
	_check(absf(meter.target - expected) < 0.02,
		"visibility meter is bound to real stealth-system values (%.3f vs %.3f)" % [meter.target, expected])

	# Full noise pipeline: real player movement -> NoiseEvents.
	_noise_events.clear()
	stealth.noise_emitted.connect(_on_noise_event)
	Input.action_press("move_right")
	await _frames(90)  # 1.5 s of movement: multiple 0.25 s cadence noise pulses
	Input.action_release("move_right")
	stealth.noise_emitted.disconnect(_on_noise_event)
	_check(_noise_events.size() >= 3,
		"player movement produces noise events through the pipeline (got %d)" % _noise_events.size())
	if _noise_events.size() > 0:
		var ev: NoiseEvent = _noise_events[0]
		_check(ev.source_id == &"player" and ev.movement_state == &"walk",
			"pipeline events carry source and movement state")
		_check(ev.position.distance_to(main_player.global_position) < 320.0,
			"noise event position tracks the player")

	# Motion feedback: visibility rose while moving, then settles back down.
	var moving_vis: float = meter.target
	await _frames(180)
	var settled_vis: float = meter.target
	_check(moving_vis > 0.30, "visibility meter shows motion boost while moving (%.2f)" % moving_vis)
	_check(settled_vis < moving_vis, "visibility decays back after stopping (%.2f vs %.2f)" % [settled_vis, moving_vis])

	main.queue_free()
	await _frames(2)
	_check(stealth.light_count() == 0, "main scene teardown unregisters its lights, got %d" % stealth.light_count())

	# ================= F. Enemy AI (Phase 3) =================
	var stealth3: Node = get_node("/root/StealthSystem")
	var p3: CharacterBody2D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	add_child(p3)
	await _frames(3)

	# F1: enemy starts in PATROL.
	var e1: CharacterBody2D = _mk_enemy(p3, Vector2(300, 200), Vector2.RIGHT)
	_check(e1.state == &"patrol", "enemy starts in PATROL")

	# F2: patrol advances toward waypoints.
	var e2: CharacterBody2D = _mk_enemy(p3, Vector2(300, 300), Vector2.RIGHT)
	e2.set_patrol_route([Vector2(300, 300), Vector2(420, 300), Vector2(300, 300)])
	await _frames(60)
	_check(e2.global_position.x > 305.0 and e2.state == &"patrol",
		"patrol advances toward the next waypoint (x=%.1f, state=%s)" % [e2.global_position.x, e2.state])

	# F3: player outside FOV is not detected.
	p3.position = Vector2(200, 200)  # behind e1 (facing right)
	p3.set_visibility(0.25)
	await _frames(20)
	_check(absf(e1.detection_strength()) < TOL and absf(e1.suspicion) < TOL,
		"player outside FOV is not detected (strength=%.3f, suspicion=%.3f)" % [e1.detection_strength(), e1.suspicion])

	# F4: player within clear FOV is eligible for detection.
	p3.position = Vector2(400, 200)
	await _frames(2)
	_check(e1.detection_strength() > 0.0,
		"player within clear FOV is eligible (strength=%.3f)" % e1.detection_strength())

	# F5: a wall blocks visual detection.
	var wall := StaticBody2D.new()
	var wall_shape := CollisionShape2D.new()
	var wall_rect := RectangleShape2D.new()
	wall_rect.size = Vector2(16.0, 96.0)
	wall_shape.shape = wall_rect
	wall.position = Vector2(350, 200)
	wall.add_child(wall_shape)
	add_child(wall)
	await _frames(5)
	_check(not e1.can_see_player() and absf(e1.suspicion) < TOL,
		"wall blocks visual detection (can_see=%s, suspicion=%.3f)" % [e1.can_see_player(), e1.suspicion])

	# F6: higher-visibility player produces stronger detection (controlled).
	wall.queue_free()
	await _frames(5)
	p3.set_visibility(1.0)
	var strength_high: float = e1.detection_strength()
	p3.set_visibility(0.25)
	var strength_low: float = e1.detection_strength()
	_check(strength_high > strength_low + 0.1,
		"high visibility detected more strongly than low (%.3f vs %.3f)" % [strength_high, strength_low])

	# F7: suspicion accumulates predictably while visible.
	p3.set_visibility(1.0)
	await _frames(12)
	var susp_a: float = e1.suspicion
	await _frames(36)
	var susp_b: float = e1.suspicion
	_check(susp_b > susp_a + TOL, "suspicion accumulates while visible (%.3f -> %.3f)" % [susp_a, susp_b])

	# F8: suspicion decays when evidence disappears.
	p3.position = Vector2(1500, 1500)  # far out of vision range
	await _frames(30)
	_check(e1.suspicion < susp_b, "suspicion decays without evidence (%.3f was %.3f)" % [e1.suspicion, susp_b])

	# F9: confirmed detection enters ALERT.
	p3.position = Vector2(400, 200)
	p3.set_visibility(1.0)
	var alerted: bool = await _await_state(e1, &"alert", 400)
	_check(alerted, "confirmed detection enters ALERT (state=%s, suspicion=%.2f)" % [e1.state, e1.suspicion])

	# F10: losing sight preserves the last known position.
	var lk: Vector2 = e1.last_known_position()
	p3.position = Vector2(400, 400)  # moved out of FOV/behind cover
	await _frames(30)
	_check(e1.last_known_position() == lk and e1.last_known_position() != p3.global_position,
		"last known position preserved after losing sight (%s, player now %s)" % [e1.last_known_position(), p3.global_position])

	# F11/F12: bounded search uses the last known position, then returns to patrol.
	var searching: bool = await _await_state(e1, &"searching", 200)
	_check(searching, "lost contact transitions to SEARCHING (state=%s)" % e1.state)
	if searching:
		var probe: Vector2 = e1.current_target()
		_check(probe.distance_to(lk) <= 120.0 and probe.distance_to(p3.global_position) > 60.0,
			"search probes near the last known position, not the hidden player (%s)" % probe)
	var patrolling_again: bool = await _await_state(e1, &"patrol", 900)
	_check(patrolling_again, "search timeout returns the enemy to PATROL (state=%s)" % e1.state)

	# F13: nearby noise triggers INVESTIGATING.
	var e3: CharacterBody2D = _mk_enemy(p3, Vector2(300, 500), Vector2.RIGHT)
	stealth3.publish_noise(Vector2(2000, 2000), 150.0, &"player", &"walk")
	await _frames(10)
	_check(e3.state == &"patrol", "noise beyond hearing range is ignored (state=%s)" % e3.state)
	stealth3.publish_noise(Vector2(360, 500), 200.0, &"player", &"walk")
	await _frames(10)
	_check(e3.state == &"investigating" and e3.last_sound_target() == Vector2(360, 500),
		"nearby noise triggers INVESTIGATING toward the sound (state=%s, target=%s)" % [e3.state, e3.last_sound_target()])

	# F15: duplicate noise does not restart the investigation.
	var inv_target: Vector2 = e3.current_target()
	stealth3.publish_noise(Vector2(361, 501), 200.0, &"player", &"walk")
	await _frames(10)
	_check(e3.state == &"investigating" and e3.current_target() == inv_target,
		"duplicate noise does not reset the investigation (state=%s)" % e3.state)

	# F16: confirmed visual contact takes priority over ordinary noise.
	var e5: CharacterBody2D = _mk_enemy(p3, Vector2(600, 200), Vector2.RIGHT)
	p3.position = Vector2(700, 200)
	p3.set_visibility(1.0)
	var e5_alerted: bool = await _await_state(e5, &"alert", 400)
	if e5_alerted:
		stealth3.publish_noise(Vector2(1200, 1200), 320.0, &"player", &"sprint")
		await _frames(20)
		_check(e5.state == &"alert" and e5.current_target().distance_to(p3.global_position) < 5.0,
			"ALERT ignores noise and keeps visual priority (state=%s)" % e5.state)
	else:
		_check(false, "F16 fixture failed: enemy did not reach ALERT")
	e5.queue_free()
	p3.position = Vector2(400, 200)

	# F17: multiple enemies maintain independent state.
	var e6: CharacterBody2D = _mk_enemy(p3, Vector2(300, 700), Vector2.RIGHT)
	var e7: CharacterBody2D = _mk_enemy(p3, Vector2(900, 700), Vector2.RIGHT)
	stealth3.publish_noise(Vector2(350, 700), 150.0, &"player", &"walk")
	await _frames(10)
	_check(e6.state == &"investigating" and e7.state == &"patrol",
		"multiple enemies keep independent states (%s vs %s)" % [e6.state, e7.state])

	# F18: enemy removal cleans up its subscription.
	var connections_before: int = stealth3.noise_emitted.get_connections().size()
	e6.queue_free()
	await _frames(3)
	var connections_after: int = stealth3.noise_emitted.get_connections().size()
	_check(connections_after == connections_before - 1,
		"removing an enemy disconnects exactly its noise subscription (%d -> %d)" % [connections_before, connections_after])
	stealth3.publish_noise(Vector2(350, 700), 150.0, &"player", &"walk")
	await _frames(5)
	_check(true, "publishing after enemy removal does not crash")

	# F19: AI decision throttling operates as configured.
	var e8: CharacterBody2D = _mk_enemy(p3, Vector2(500, 700), Vector2.RIGHT)
	e8.ai_interval = 0.05
	var e9: CharacterBody2D = _mk_enemy(p3, Vector2(600, 700), Vector2.RIGHT)
	e9.ai_interval = 0.25
	await _frames(90)  # ~1.5 s of physics time
	_check(e8.decision_ticks >= 15 and e9.decision_ticks >= 3 and e9.decision_ticks * 2 <= e8.decision_ticks,
		"AI throttling matches the configured interval (fast=%d, slow=%d ticks)" % [e8.decision_ticks, e9.decision_ticks])

	# F20: missing player references do not crash the scene.
	var e10: CharacterBody2D = _mk_enemy(p3, Vector2(700, 500), Vector2.RIGHT)
	e10.set_player(null)
	await _frames(30)
	_check(e10.state == &"patrol", "enemy with no player reference keeps running (state=%s)" % e10.state)
	var doomed: CharacterBody2D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	add_child(doomed)
	e10.set_player(doomed)
	doomed.queue_free()
	await _frames(30)
	_check(e10.state == &"patrol", "enemy survives the player reference being freed (state=%s)" % e10.state)

	p3.queue_free()
	for child: Node in get_children():
		if child is Enemy:
			child.queue_free()

	# ================= G. Level generation and layouts (Phase 4) =================
	await _frames(5)  # let section F teardown (queue_free) settle first
	var stealth4: Node = get_node("/root/StealthSystem")
	var base_conn: int = stealth4.noise_emitted.get_connections().size()

	# G1/G2/G3: authored layouts load, dimensions valid, real walls, doors.
	var joined_rows: Dictionary = {}
	for descriptor: Dictionary in LevelCatalog.AUTHORED_LAYOUTS:
		var gen: Node2D = (load("res://scripts/level_generator.gd") as GDScript).new()
		add_child(gen)
		await _frames(2)
		var data: Dictionary = gen.generate(descriptor["rows"], descriptor.get("zones", []))
		_check(data["grid_size"] == Vector2i(28, 16) and data["bounds"].size == Vector2(1344.0, 768.0),
			"layout '%s' loads with valid grid dimensions" % descriptor["label"])
		_check(gen.get_node("Walls").get_child_count() >= 20,
			"layout '%s' wall cells generate real collision bodies" % descriptor["label"])
		var vr: Dictionary = LevelCatalog.validate_rows(descriptor["rows"])
		_check(vr["valid"], "layout '%s' validates (markers, doors, reachability)" % descriptor["label"])
		var five_count: int = 0
		var term_count: int = 0
		for row: String in descriptor["rows"]:
			five_count += row.count("5")
			term_count += row.count("3")
		_check(data["enemy_spawns"].size() == five_count and data["terminals"].size() == term_count,
			"layout '%s' markers collect correctly (enemies %d, terminals %d)" % [descriptor["label"], five_count, term_count])
		joined_rows[descriptor["label"]] = "|".join(descriptor["rows"])
		gen.queue_free()
		await _frames(2)

	# G4: authored maps differ structurally.
	_check(joined_rows.size() == 3 and joined_rows["legacy"] != joined_rows["layout_b"]
		and joined_rows["layout_b"] != joined_rows["layout_c"]
		and joined_rows["legacy"] != joined_rows["layout_c"],
		"three authored layouts are structurally distinct")

	# G5: same seed reproduces the same logical level.
	var l42a: Dictionary = LevelCatalog.generate_layout(42)
	var l42b: Dictionary = LevelCatalog.generate_layout(42)
	_check("|".join(l42a["rows"]) == "|".join(l42b["rows"]) and str(l42a["zones"]) == str(l42b["zones"])
		and l42a["attempts"] == l42b["attempts"],
		"same seed reproduces the same logical level")

	# G6: different seeds produce meaningfully different valid layouts.
	var seed_rows: Dictionary = {}
	var all_distinct: bool = true
	for seed in [1, 2, 3]:
		var desc: Dictionary = LevelCatalog.generate_layout(seed)
		var ok: Dictionary = LevelCatalog.validate_rows(desc["rows"])
		_check(ok["valid"] and desc["fallback"] == false,
			"seed %d produces a valid generated level" % seed)
		seed_rows[seed] = "|".join(desc["rows"])
	for a in seed_rows:
		for b in seed_rows:
			if a < b and seed_rows[a] == seed_rows[b]:
				all_distinct = false
	_check(all_distinct and seed_rows.size() == 3, "different seeds produce different layouts")

	# G7: generation is bounded.
	_check(l42a["attempts"] >= 1 and l42a["attempts"] <= LevelCatalog.MAX_ATTEMPTS,
		"generation stays within the attempt limit (attempts=%d)" % l42a["attempts"])

	# G8: negative/odd seeds handled predictably.
	var neg: Dictionary = LevelCatalog.generate_layout(-5)
	var neg_valid: Dictionary = LevelCatalog.validate_rows(neg["rows"])
	_check(neg_valid["valid"] and (neg["fallback"] == false or neg.has("reason")),
		"negative seed handled predictably (fallback=%s)" % neg["fallback"])

	# G9-G12: marker placement validity for every authored layout.
	for descriptor: Dictionary in LevelCatalog.AUTHORED_LAYOUTS:
		var rows_a: Array = descriptor["rows"]
		var exp_spawn: Vector2 = _marker_center(rows_a, "4")
		var exp_extract: Vector2 = _marker_center(rows_a, "6")
		var gen2: Node2D = (load("res://scripts/level_generator.gd") as GDScript).new()
		add_child(gen2)
		await _frames(2)
		var data2: Dictionary = gen2.generate(rows_a, [])
		_check(data2["spawn"] == exp_spawn and data2["extraction"] == exp_extract,
			"layout '%s' spawn and extraction match grid cell centers" % descriptor["label"])
		var enemy_ok: bool = data2["enemy_spawns"].size() > 0
		for sp: Vector2 in data2["enemy_spawns"]:
			if sp != _marker_center_of(rows_a, sp):
				enemy_ok = false
		_check(enemy_ok, "layout '%s' enemy spawns sit on '5' cells, never walls" % descriptor["label"])
		gen2.queue_free()
		await _frames(2)

	# G13/G14: reachability (extraction + objectives) via the validator.
	var reach_all: bool = true
	for descriptor: Dictionary in LevelCatalog.AUTHORED_LAYOUTS:
		var v2: Dictionary = LevelCatalog.validate_rows(descriptor["rows"])
		if not v2["valid"]:
			reach_all = false
	_check(reach_all, "all authored objectives and extractions are reachable")

	# G15: invalid candidates are rejected with reasons.
	var bad_rows: Array[String] = [
		"222222222222",
		"202222222222",
		"223222222222",
		"202222222222",
		"200000000002",
		"200004000002",
		"200000000002",
		"200050000002",
		"200000000002",
		"200000000062",
		"200000000002",
		"222222222222",
	]
	var vbad: Dictionary = LevelCatalog.validate_rows(bad_rows)
	_check(not vbad["valid"] and vbad["reason"].contains("unreachable"),
		"isolated terminal is rejected ('%s')" % vbad["reason"])
	var door_rows: Array[String] = [
		"222222222222",
		"243000000002",
		"200000000002",
		"200000000002",
		"200000000002",
		"200007000002",
		"200000000002",
		"200000000002",
		"200050000002",
		"200000000062",
		"200000000002",
		"222222222222",
	]
	var vdoor: Dictionary = LevelCatalog.validate_rows(door_rows)
	_check(not vdoor["valid"] and vdoor["reason"].contains("single-tile"),
		"door in open space is rejected ('%s')" % vdoor["reason"])

	# G16-G19: door collision, vision and navigation behavior (layout B).
	var genB: Node2D = (load("res://scripts/level_generator.gd") as GDScript).new()
	add_child(genB)
	await _frames(2)
	var dataB: Dictionary = genB.generate(LevelCatalog.LAYOUT_B["rows"], LevelCatalog.LAYOUT_B["zones"])
	await _frames(2)
	_check(dataB["doors"].size() == 4 and dataB["door_cells"].has(Vector2i(11, 4)),
		"layout B creates 4 door objects at grid door cells")
	for door: Node in dataB["doors"]:
		stealth4.register_door(door)
	stealth4.configure(dataB["lit_cells"], dataB["cell_size"], dataB["origin"], dataB["wall_cells"])

	var door0: Node = dataB["doors"][0]
	var p4: CharacterBody2D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	add_child(p4)
	await _frames(3)
	p4.position = Vector2(600.0, 216.0)
	p4.set_visibility(1.0)
	var e_vis: CharacterBody2D = _mk_enemy(p4, Vector2(504.0, 216.0), Vector2.RIGHT)
	await _frames(20)
	_check(absf(e_vis.detection_strength()) < TOL,
		"closed door obstructs enemy vision (strength=%.3f)" % e_vis.detection_strength())
	door0.set_state(true)
	await _frames(10)
	_check(e_vis.detection_strength() > 0.0,
		"open door permits vision through the doorway (strength=%.3f)" % e_vis.detection_strength())
	door0.set_state(false)
	await _frames(10)
	_check(absf(e_vis.detection_strength()) < TOL,
		"re-closing the door restores vision obstruction")
	_check(stealth4.is_cell_blocked(Vector2i(11, 4)) and not stealth4.is_cell_blocked(Vector2i(10, 4)),
		"navigation queries reflect the live door state")
	e_vis.set_player(null)
	e_vis.queue_free()
	await _frames(4)  # free the corridor before the movement test

	# Movement: closed door blocks, open door permits.
	p4.position = Vector2(504.0, 216.0)
	await _frames(5)
	Input.action_press("move_right")
	await _frames(60)
	Input.action_release("move_right")
	_check(p4.global_position.x < 528.0,
		"closed door blocks player movement (x=%.1f)" % p4.global_position.x)
	door0.set_state(true)
	await _frames(2)
	Input.action_press("move_right")
	await _frames(90)
	Input.action_release("move_right")
	_check(p4.global_position.x > 600.0,
		"open door permits player movement (x=%.1f)" % p4.global_position.x)

	# G20/G21: restricted-zone metadata.
	var zones_b: Array = LevelCatalog.LAYOUT_B["zones"]
	_check(LevelCatalog.zone_at(zones_b, Vector2(700.0, 150.0), 48.0, Vector2.ZERO) == &"zone_north_lab",
		"zone membership queried by world position")
	_check(LevelCatalog.zone_at(zones_b, Vector2(700.0, 20.0), 48.0, Vector2.ZERO) == &"",
		"position outside zone rectangles returns no zone")
	_check(LevelCatalog.zone_at(zones_b, Vector2(24.0, 24.0), 48.0, Vector2.ZERO) == &"",
		"zone boundary is deterministic (corner outside)")
	var overlap_zones: Array = [
		{"id": &"zone_x", "rect": Rect2i(1, 1, 5, 5)},
		{"id": &"zone_y", "rect": Rect2i(3, 3, 5, 5)},
	]
	var voverlap: Dictionary = LevelCatalog.validate_zones(overlap_zones, LevelCatalog.LAYOUT_B["rows"])
	_check(not voverlap["valid"] and voverlap["reason"].contains("overlap"),
		"overlapping restricted zones with different ids are rejected")

	# G24 (authored): static lighting matches the generated grid.
	var lit_expected: Dictionary = _expected_lit(LevelCatalog.LAYOUT_B["rows"])
	_check(dataB["lit_cells"].size() == lit_expected.size() and _same_keys(dataB["lit_cells"], lit_expected),
		"layout B static illumination matches its '1' cells (%d cells)" % lit_expected.size())
	var l42: Dictionary = LevelCatalog.generate_layout(42)
	var gen42: Node2D = (load("res://scripts/level_generator.gd") as GDScript).new()
	add_child(gen42)
	await _frames(2)
	var data42: Dictionary = gen42.generate(l42["rows"], l42.get("zones", []))
	var lit42: Dictionary = _expected_lit(l42["rows"])
	_check(data42["lit_cells"].size() == lit42.size() and _same_keys(data42["lit_cells"], lit42),
		"seeded layout static illumination matches its '1' cells (%d cells)" % lit42.size())
	gen42.queue_free()

	# G29: representative fixed seeds produce valid maps (bounded property set).
	var seeds_ok: bool = true
	for seed in [7, 123, 999, 2026, 55]:
		var d2: Dictionary = LevelCatalog.generate_layout(seed)
		var ok2: Dictionary = LevelCatalog.validate_rows(d2["rows"])
		if not ok2["valid"] or d2["attempts"] > LevelCatalog.MAX_ATTEMPTS:
			seeds_ok = false
	_check(seeds_ok, "representative seeds 7/123/999/2026/55 all generate valid levels")
	var property_ok: bool = true
	for seed in range(1, 11):
		var d3: Dictionary = LevelCatalog.generate_layout(seed)
		var ok3: Dictionary = LevelCatalog.validate_rows(d3["rows"])
		if not ok3["valid"] or d3["fallback"]:
			property_ok = false
	_check(property_ok, "bounded multi-seed property: seeds 1-10 all valid")

	# Fixture cleanup before the main-scene lifecycle block.
	# (e_vis was already freed before the movement test.)
	p4.queue_free()
	for child_g: Node in get_children():
		if child_g is Door or (child_g is Node2D and child_g.get_script() == load("res://scripts/level_generator.gd")):
			child_g.queue_free()
	stealth4.clear_doors()
	await _frames(4)

	# G22/G23/G25/G26/G27/G28: level lifecycle through the main scene.
	var main2: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main2)
	await _frames(12)
	_check(main2.level_label == "legacy", "main scene boots the legacy regression fixture")
	await main2.load_level(LevelCatalog.LAYOUT_B)
	await _frames(6)
	_check(main2.enemies.size() == 2 and StealthSystem.light_count() == 3,
		"switching to layout B spawns 2 enemies and 3 lamps (got %d enemies, %d lights)" % [main2.enemies.size(), StealthSystem.light_count()])
	var b_patrol: bool = true
	for e_b: Node in main2.enemies:
		if e_b.state != &"patrol":
			b_patrol = false
	_check(b_patrol, "layout B enemies start in PATROL")
	await main2.load_level(LevelCatalog.LAYOUT_C)
	await _frames(6)
	_check(main2.enemies.size() == 3 and StealthSystem.light_count() == 2,
		"switching to layout C respawns cleanly (3 enemies, 2 lights, no duplicates)")
	_check(StealthSystem.noise_emitted.get_connections().size() == base_conn + 3,
		"enemy noise subscriptions match the live enemy count exactly")
	var routes_ok: bool = true
	for e_c: Node in main2.enemies:
		for wp: Vector2 in e_c.patrol_route():
			if StealthSystem.is_cell_blocked(stealth4.world_to_grid(wp)):
				routes_ok = false
	_check(routes_ok, "layout C patrol routes avoid walls and closed doors")
	_check(LevelCatalog.zone_at(main2.level_data["zones"], Vector2(720.0, 384.0), 48.0, Vector2.ZERO) == &"zone_vault",
		"layout C restricted vault zone is queryable")

	main2.queue_free()
	await _frames(6)
	_check(StealthSystem.light_count() == 0 and stealth4.noise_emitted.get_connections().size() == base_conn,
		"level teardown clears light registrations and noise subscriptions")
	_check(not stealth4.is_cell_blocked(Vector2i(7, 7)),
		"door registrations are cleared after teardown")

	# ================= H. Mission gameplay (Phase 5) =================
	await _frames(5)  # let section G teardown settle
	var m5: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(m5)
	await _frames(12)
	var mm: MissionManager = m5.mission_manager
	var ev := {"succeeded": 0, "failed": 0, "progress": [], "zones": [], "rejected": 0, "extract": []}
	mm.mission_succeeded.connect(func(): ev["succeeded"] += 1)
	mm.mission_failed.connect(func(_r): ev["failed"] += 1)
	mm.objective_progress_changed.connect(func(done, total): ev["progress"].append([done, total]))
	mm.restricted_zone_changed.connect(func(z): ev["zones"].append(z))
	mm.mission_rejected.connect(func(_r): ev["rejected"] += 1)
	mm.extraction_availability_changed.connect(func(av): ev["extract"].append(av))

	# H01/H02: mission initializes correctly from the legacy level.
	_check(mm.state == MissionManager.State.ACTIVE and mm.objectives_total() == 1
		and mm.objectives_done() == 0,
		"mission initializes ACTIVE with the level's objective count (%d/%d)" % [mm.objectives_done(), mm.objectives_total()])

	# H03: terminal object at the marker cell center with a stable id.
	var term0: Node = m5.level_data["terminals"][0]
	_check(term0.terminal_id == &"terminal_1" and term0.global_position == Vector2(1224.0, 72.0)
		and not term0.is_completed(),
		"terminal spawns at the '3' cell center with stable id")

	# H04: interaction outside range is rejected (genuine input action).
	m5.player.global_position = Vector2(72.0, 72.0)
	await _frames(3)
	Input.action_press("interact")
	await _frames(3)
	Input.action_release("interact")
	_check(not term0.is_completed() and mm.objectives_done() == 0,
		"interaction outside range does nothing (objectives %d)" % mm.objectives_done())

	# H12/H13: early extraction does nothing while objectives incomplete.
	m5.player.global_position = Vector2(1128.0, 600.0)
	await _frames(30)
	_check(mm.state == MissionManager.State.ACTIVE and not mm.extraction_available(),
		"reaching extraction early does not win the mission")

	# H05 (touch contract): in-range interaction completes the terminal.
	m5.player.global_position = Vector2(1224.0, 120.0)
	await _frames(3)
	(m5.get_node("UI/TouchLayer") as Control).interact_pressed.emit()
	await _frames(3)
	_check(term0.is_completed() and mm.objectives_done() == 1,
		"in-range touch interaction completes the terminal")

	# H09/H10: repeated activation does not double-count; progress updates.
	Input.action_press("interact")
	await _frames(3)
	Input.action_release("interact")
	_check(not term0.complete() and mm.objectives_done() == 1 and ev["progress"].has([1, 1]),
		"duplicate completion rejected and progress event delivered")

	# H36 end-to-end (keyboard path): complete -> unlock -> extract -> success.
	await m5.restart_mission()
	await _frames(4)
	m5.player.global_position = Vector2(1224.0, 120.0)
	await _frames(2)
	Input.action_press("interact")
	await _frames(3)
	Input.action_release("interact")
	_check(mm.objectives_done() == 1 and mm.extraction_available(),
		"keyboard interaction completes the objective and unlocks extraction")
	m5.player.global_position = Vector2(1128.0, 600.0)
	await _frames(4)
	_check(mm.state == MissionManager.State.SUCCEEDED and ev["succeeded"] == 1,
		"entering extraction after completion triggers success exactly once")
	await _frames(30)
	_check(ev["succeeded"] == 1 and mm.state == MissionManager.State.SUCCEEDED,
		"success occurs exactly once (no repeated transitions)")

	# H17: success prevents later failure (a 0.2 s grace would fail fast).
	mm.detection_grace = 0.2
	var e_s: CharacterBody2D = _mk_main_enemy(m5, Vector2(72.0, 168.0), Vector2(0, -1))
	m5.player.global_position = Vector2(72.0, 72.0)
	await _frames(40)
	_check(mm.state == MissionManager.State.SUCCEEDED and ev["failed"] == 0,
		"no failure transition after success")

	# --- detection rules (legacy map) ---
	await m5.restart_mission()
	mm.detection_grace = 1.0
	await _frames(4)

	# H22/H23: suspicion/noise alone never fail.
	m5.player.global_position = Vector2(72.0, 72.0)
	var e_noise: CharacterBody2D = _mk_main_enemy(m5, Vector2(72.0, 168.0), Vector2(0, 1))  # facing away
	StealthSystem.publish_noise(Vector2(72.0, 168.0), 200.0, &"player", &"walk")
	await _frames(90)
	_check(mm.state == MissionManager.State.ACTIVE and absf(mm.detection_timer) < TOL
		and e_noise.state != &"patrol",
		"noise investigation alone does not fill the detection timer (state=%s)" % e_noise.state)

	# H24: sustained confirmed visual detection triggers failure.
	var e_det: CharacterBody2D = _mk_main_enemy(m5, Vector2(72.0, 168.0), Vector2(0, -1))
	await _frames(80)
	_check(mm.state == MissionManager.State.FAILED and ev["failed"] >= 1,
		"sustained genuine visual detection fails the mission")

	# H25: breaking line of sight resets the timer (documented rule).
	await m5.restart_mission()
	await _frames(2)
	var e_los: CharacterBody2D = _mk_main_enemy(m5, Vector2(72.0, 168.0), Vector2(0, -1))
	await _frames(30)
	var t_mid: float = mm.detection_timer
	m5.player.global_position = Vector2(1500.0, 1500.0)
	await _frames(5)
	_check(t_mid > 0.05 and absf(mm.detection_timer) < TOL,
		"losing line of sight fully resets the detection timer (%.3f -> %.3f)" % [t_mid, mm.detection_timer])
	await _frames(90)
	_check(mm.state == MissionManager.State.ACTIVE,
		"no failure after contact ends (timer rule honored)")

	# H26: restricted-zone detection follows the documented 2x pressure rule.
	await m5.restart_mission()
	await _frames(2)
	m5.player.global_position = Vector2(720.0, 264.0)  # inside zone_hall
	var e_zone: CharacterBody2D = _mk_main_enemy(m5, Vector2(720.0, 168.0), Vector2(0, 1))
	await _frames(40)  # 0.67 s: 2x rate reaches the 1.0 s grace
	_check(mm.state == MissionManager.State.FAILED,
		"genuine detection inside a restricted zone fails faster (2x pressure)")
	await m5.restart_mission()
	await _frames(2)
	m5.player.global_position = Vector2(72.0, 72.0)  # outside every zone
	var e_norm: CharacterBody2D = _mk_main_enemy(m5, Vector2(72.0, 168.0), Vector2(0, -1))
	await _frames(40)
	_check(mm.state == MissionManager.State.ACTIVE,
		"same detection outside a restricted zone has not failed yet (1x rate)")

	# H27: multiple enemies never multiply detection pressure.
	await m5.restart_mission()
	await _frames(2)
	var e_m1: CharacterBody2D = _mk_main_enemy(m5, Vector2(72.0, 168.0), Vector2(0, -1))
	var e_m2: CharacterBody2D = _mk_main_enemy(m5, Vector2(168.0, 72.0), Vector2(-1, 0))
	await _frames(40)
	_check(mm.state == MissionManager.State.ACTIVE,
		"two seeing enemies do not double the failure rate")
	await _frames(40)
	_check(mm.state == MissionManager.State.FAILED and ev["failed"] >= 2,
		"failure eventually occurs once, regardless of enemy count")

	# H18: failure prevents later success.
	m5.player.global_position = Vector2(1128.0, 600.0)
	await _frames(30)
	_check(mm.state == MissionManager.State.FAILED and ev["succeeded"] == 1,
		"no success transition after failure (early extraction ignored)")

	# H19/H20/H21: restricted-zone tracking, entry/exit, no repeats.
	await m5.restart_mission()
	mm.detection_grace = 3.0
	await _frames(2)
	var zone_events_before: int = (ev["zones"] as Array).size()
	m5.player.global_position = Vector2(720.0, 264.0)
	await _frames(30)
	_check(mm.current_zone == &"zone_hall" and (ev["zones"] as Array).size() == zone_events_before + 1,
		"restricted-zone entry detected once")
	m5.player.global_position = Vector2(1500.0, 1500.0)
	await _frames(5)
	_check(mm.current_zone == &"" and (ev["zones"] as Array).size() == zone_events_before + 2,
		"zone exit clears the tracked zone exactly once")

	# H34/H35: freed terminal/enemy references stay safe.
	var term_free: Node = m5.level_data["terminals"][0]
	term_free.queue_free()
	await _frames(3)
	m5.player.global_position = Vector2(1224.0, 120.0)
	var target_after_free: Node = m5._find_interact_target(true)
	_check(target_after_free == null and mm.state == MissionManager.State.ACTIVE,
		"mission remains safe when a terminal is freed")
	var e_free: CharacterBody2D = _mk_main_enemy(m5, Vector2(168.0, 72.0), Vector2(-1, 0))
	e_free.queue_free()
	await _frames(5)
	_check(mm.state == MissionManager.State.ACTIVE,
		"mission remains safe when an enemy is freed")

	# --- layout B: doors, obstruction, tie-breaking, restart ---
	await m5.load_level(LevelCatalog.LAYOUT_B)
	await _frames(6)
	_check(mm.state == MissionManager.State.ACTIVE and mm.objectives_total() == 2,
		"layout B mission starts with its own objective count (2)")
	m5.interaction_radius = 320.0
	var term_b1: Node = m5.level_data["terminals"][0]
	var term_b2: Node = m5.level_data["terminals"][1]
	var door_b: Node = null
	for d_b: Node in m5.level_data["doors"]:
		if d_b.cell == Vector2i(11, 4):
			door_b = d_b
	_check(door_b != null and not door_b.is_open and mm.objectives_done() == 0,
		"fresh mission starts with closed doors and no completed objectives")

	# H06: interaction through an obstructing wall is rejected.
	m5.player.global_position = Vector2(408.0, 408.0)
	await _frames(3)
	Input.action_press("interact")
	await _frames(3)
	Input.action_release("interact")
	_check(not term_b1.is_completed(),
		"terminal behind a solid wall cannot be used at radial distance")

	# H07: closed door obstructs the terminal behind it (door is the target).
	m5.player.global_position = Vector2(504.0, 216.0)
	await _frames(3)
	var tgt_closed: Node = m5._find_interact_target(true)
	_check(tgt_closed is Door,
		"closed door takes target priority: terminal behind it is obstructed")

	# H08/H28: one press activates exactly one target (nearest).
	m5.interaction_radius = 100.0
	m5.player.global_position = Vector2(456.0, 216.0)
	await _frames(3)
	Input.action_press("interact")
	await _frames(3)
	Input.action_release("interact")
	_check(term_b1.is_completed() and not door_b.is_open,
		"one press activates only the nearest eligible target (terminal, not door)")

	# H29: opening the door makes the passage usable for interaction.
	m5.interaction_radius = 320.0
	m5.player.global_position = Vector2(600.0, 216.0)
	await _frames(3)
	Input.action_press("interact")
	await _frames(3)
	Input.action_release("interact")
	_check(door_b.is_open,
		"nearby door interaction opens the door")
	var tgt_open: Node = m5._find_interact_target(true)
	_check(tgt_open is Terminal,
		"open door no longer obstructs the terminal beyond it")

	# H11: second terminal completes independently; H37: full B loop.
	m5.player.global_position = Vector2(792.0, 264.0)
	await _frames(2)
	Input.action_press("interact")
	await _frames(3)
	Input.action_release("interact")
	_check(term_b2.is_completed() and mm.objectives_done() == 2 and mm.extraction_available(),
		"multiple terminals complete independently and unlock extraction")
	m5.player.global_position = Vector2(1272.0, 648.0)
	await _frames(4)
	_check(mm.state == MissionManager.State.SUCCEEDED,
		"layout B full mission loop succeeds (terminals -> extraction)")

	# H30/H31/H32: restart clears objective records, doors, timers, zones.
	var zone_id_now: StringName = mm.current_zone
	var success_before: int = ev["succeeded"]
	await m5.restart_mission()
	await _frames(4)
	_check(mm.state == MissionManager.State.ACTIVE and mm.objectives_done() == 0
		and not is_instance_valid(term_b1) and mm.detection_timer == 0.0 and mm.current_zone == &"",
		"restart clears objectives, detection and zone state")

	# H33: no subscription leaks across restart.
	var mm_conns: int = mm.objective_completed.get_connections().size()
	var noise_conns: int = StealthSystem.noise_emitted.get_connections().size()
	await m5.restart_mission()
	await _frames(4)
	_check(mm.objective_completed.get_connections().size() == mm_conns
		and StealthSystem.noise_emitted.get_connections().size() == noise_conns,
		"restart leaks no mission or noise subscriptions")

	# H38: layout C full loop (restricted vault).
	await m5.load_level(LevelCatalog.LAYOUT_C)
	await _frames(6)
	_check(mm.state == MissionManager.State.ACTIVE and mm.objectives_total() == 1,
		"layout C mission starts correctly (vault terminal)")
	m5.player.global_position = Vector2(648.0, 360.0)
	await _frames(2)
	Input.action_press("interact")
	await _frames(3)
	Input.action_release("interact")
	m5.player.global_position = Vector2(1272.0, 648.0)
	await _frames(4)
	_check(mm.state == MissionManager.State.SUCCEEDED and mm.objectives_done() == 1,
		"layout C full mission loop succeeds")

	# H41: switching layouts does not carry over mission completion.
	await m5.load_level(LevelCatalog.LAYOUT_B)
	await _frames(6)
	_check(mm.state == MissionManager.State.ACTIVE and mm.objectives_done() == 0
		and not mm.extraction_available(),
		"loading another layout starts a fresh mission with no carried progress")

	# H39: seeded layout supports a complete mission loop.
	mm.detection_grace = 10.0
	var seeded_desc: Dictionary = LevelCatalog.generate_layout(42)
	await m5.load_level(seeded_desc)
	await _frames(6)
	var seeded_terminals: Array[Vector2] = _all_marker_centers(seeded_desc["rows"], "3")
	var seeded_extract: Vector2 = _marker_center(seeded_desc["rows"], "6")
	for st: Vector2 in seeded_terminals:
		m5.player.global_position = st
		await _frames(2)
		Input.action_press("interact")
		await _frames(3)
		Input.action_release("interact")
	mm.detection_grace = 3.0
	m5.player.global_position = seeded_extract
	await _frames(4)
	_check(mm.state == MissionManager.State.SUCCEEDED and mm.objectives_done() == seeded_terminals.size(),
		"seeded layout supports the full mission loop (%d objectives)" % seeded_terminals.size())

	# H40: same seed -> same mission-objective structure.
	var s42a: Dictionary = LevelCatalog.generate_layout(42)
	var s42b: Dictionary = LevelCatalog.generate_layout(42)
	_check(_all_marker_centers(s42a["rows"], "3") == _all_marker_centers(s42b["rows"], "3")
		and _marker_center(s42a["rows"], "6") == _marker_center(s42b["rows"], "6"),
		"same seed produces the same mission-objective structure")

	# H43: invalid mission metadata is rejected, never falsely successful.
	var mm_bad: MissionManager = MissionManager.new()
	add_child(mm_bad)
	var bad_data: Dictionary = m5.level_data.duplicate()
	bad_data.erase("extraction")
	mm_bad.start_mission(bad_data, [])
	var rejected_1: bool = mm_bad.state == MissionManager.State.READY
	var bad_data2: Dictionary = m5.level_data.duplicate()
	bad_data2["terminals"] = []
	mm_bad.start_mission(bad_data2, [])
	_check(rejected_1 and mm_bad.state == MissionManager.State.READY,
		"missing extraction or objectives reject the mission (no false success)")
	mm_bad.queue_free()

	# H44/H45 are covered by the full suite: all previous sections plus
	# this one run against the final tree; the pipeline check runs after.

	m5.queue_free()
	await _frames(6)
	_check(StealthSystem.light_count() == 0,
		"final mission fixture tears down cleanly")

	# ================= I. Mobile polish (Phase 6) =================
	# --- P6-T1: camera smoothing and bounds ---
	var noise_base6: int = StealthSystem.noise_emitted.get_connections().size()
	var m6: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(m6)
	await _frames(12)
	var pl: CharacterBody2D = m6.player
	var cam: Camera2D = pl.camera
	_check(cam.position_smoothing_enabled and absf(cam.position_smoothing_speed
		- pl.CAMERA_SMOOTHING_SPEED) < TOL,
		"camera smoothing enabled with configurable speed")
	_check(cam.global_position == Vector2(72.0, 72.0),
		"camera initializes exactly at the player spawn (no drift)")
	# Limit rule mirrored against the ACTUAL runtime viewport (headless
	# viewport size differs from the design size; the rule is what counts).
	var vp6: Vector2 = m6.get_viewport_rect().size
	var limits_ok: bool = true
	if 1344 >= vp6.x:
		limits_ok = limits_ok and cam.limit_left == 0 and cam.limit_right == 1344
	else:
		limits_ok = limits_ok and cam.limit_right >= 1000000 - 1
	if 768 >= vp6.y:
		limits_ok = limits_ok and cam.limit_top == 0 and cam.limit_bottom == 768
	else:
		limits_ok = limits_ok and cam.limit_bottom >= 1000000 - 1
	_check(limits_ok, "camera limits follow the map-bounds rule for the runtime viewport")

	# Smooth follow: teleport, convergence without overshoot.
	pl.global_position = Vector2(600.0, 400.0)
	var prev_dist: float = cam.global_position.distance_to(pl.global_position)
	var overshoot: bool = false
	for _i in range(30):
		await _frames(1)
		var d_now: float = cam.global_position.distance_to(pl.global_position)
		if d_now > prev_dist + 0.5:
			overshoot = true
		prev_dist = d_now
	_check(prev_dist < 60.0 and not overshoot,
		"camera converges smoothly toward the player without overshoot (%.1f px left)" % prev_dist)

	# Stationary stability.
	await _frames(20)
	var cam_pos_a: Vector2 = cam.global_position
	await _frames(20)
	_check(cam.global_position == cam_pos_a,
		"camera is perfectly stable while the player is stationary")

	# Bounds at the map corner: the camera still tracks the player and the
	# limits form a valid clamp window. (View-space clamping itself is
	# applied by the renderer at draw time - a device-level concern that
	# cannot be asserted headless; the limit rule is verified instead.)
	pl.global_position = Vector2(48.0, 48.0)
	cam.reset_smoothing()
	await _frames(2)
	_check(cam.global_position == pl.global_position
		and (cam.limit_right - cam.limit_left) >= int(vp6.x)
		and (cam.limit_bottom - cam.limit_top) >= int(vp6.y),
		"camera tracks the player at the corner with a valid clamp window")

	# Small map: no inverted limits.
	var small_rows: Array[String] = []
	small_rows.resize(6)
	for y in range(6):
		small_rows[y] = "20000000200000002"
	small_rows[1] = "20400000200000002"
	small_rows[2] = "20003000200000002"
	small_rows[3] = "20000000200000502"
	small_rows[4] = "20000000200000002"
	small_rows[5] = "20000000600000002"
	var small_desc: Dictionary = {"label": "small", "rows": small_rows, "zones": []}
	await m6.load_level(small_desc)
	await _frames(4)
	var cam_small: Camera2D = (m6.player as CharacterBody2D).camera
	_check(cam_small.limit_left < cam_small.limit_right and cam_small.limit_top < cam_small.limit_bottom
		and cam_small.limit_right >= 1000000 - 1,
		"small map keeps camera limits valid (unlimited, not inverted)")
	_check(cam_small.global_position == (m6.player as CharacterBody2D).global_position,
		"camera snaps to the player on small-map load")

	# Restart and level-switch camera reset.
	await m6.load_level(LevelCatalog.default_descriptor())
	await _frames(4)
	_check((m6.player as CharacterBody2D).camera.global_position == Vector2(72.0, 72.0),
		"camera resets to spawn on level switch / restart")

	# Freed-player safety: camera is the player's child, so it dies with
	# it - no stale reference can survive (verified on a lone instance).
	var pl_lone: CharacterBody2D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	add_child(pl_lone)
	var cam_lone: Camera2D = pl_lone.camera
	pl_lone.queue_free()
	await _frames(3)
	_check(not is_instance_valid(cam_lone),
		"freeing the player frees its camera (no stale references)")

	# --- P6-T1: animation states ---
	var st_events: Array = []
	(m6.player as CharacterBody2D).movement_state_changed.connect(
		func(new_st, _old): st_events.append(new_st))
	_check((m6.player as CharacterBody2D).movement_visual_state
		== Player.MovementVisualState.IDLE,
		"player starts in IDLE visual state")
	Input.action_press("move_right")
	await _frames(12)
	_check((m6.player as CharacterBody2D).movement_visual_state
		== Player.MovementVisualState.WALK,
		"IDLE -> WALK transition on real movement")
	Input.action_press("sprint")
	await _frames(8)
	_check((m6.player as CharacterBody2D).movement_visual_state
		== Player.MovementVisualState.SPRINT,
		"WALK -> SPRINT transition on genuine sprint")
	Input.action_release("sprint")
	Input.action_press("crouch")
	await _frames(8)
	_check((m6.player as CharacterBody2D).movement_visual_state
		== Player.MovementVisualState.CROUCH,
		"WALK -> CROUCH transition reflects the real crouch state")
	Input.action_release("move_right")
	Input.action_release("crouch")
	await _frames(25)
	_check((m6.player as CharacterBody2D).movement_visual_state
		== Player.MovementVisualState.IDLE,
		"reliable return to IDLE after input release")
	_check(st_events.size() == 5,
		"every transition emits exactly one signal; residual-speed CROUCH->WALK->IDLE is genuine (%d events)" % st_events.size())
	Input.action_press("move_left")
	await _frames(6)
	_check((m6.player as CharacterBody2D).facing.x < 0.0,
		"facing direction follows movement coherently")
	Input.action_release("move_left")
	await _frames(6)
	Input.action_press("move_right")
	await _frames(6)
	Input.action_release("move_right")
	_check((m6.player as CharacterBody2D).facing == Vector2(1.0, 0.0),
		"keyboard and touch share one facing rule (axis-coherent)")

	# --- P6-T2: feedback layer ---
	var fm: FeedbackManager = m6.feedback_manager
	var audio_ev: Array = []
	var haptic_ev: Array = []
	fm.audio_played.connect(func(e): audio_ev.append(e))
	fm.haptic_event.connect(func(ms): haptic_ev.append(ms))
	_check(fm.get_child_count() == 5,
		"feedback manager owns one audio player per event type")

	# Event routing through real gameplay (terminal on the legacy map).
	await m6.restart_mission()
	await _frames(4)
	(m6.player as CharacterBody2D).global_position = Vector2(1224.0, 120.0)
	await _frames(2)
	Input.action_press("interact")
	await _frames(3)
	Input.action_release("interact")
	_check(audio_ev.count(&"terminal") == 1 and haptic_ev.size() == 1,
		"terminal completion routes one audio event and one haptic request")

	# Door event.
	await m6.load_level(LevelCatalog.LAYOUT_B)
	await _frames(4)
	(m6.player as CharacterBody2D).global_position = Vector2(600.0, 216.0)
	m6.interaction_radius = 320.0
	await _frames(3)
	Input.action_press("interact")
	await _frames(3)
	Input.action_release("interact")
	_check(audio_ev.count(&"door") == 1,
		"door interaction routes a door audio event")

	# Warning cooldown: two rapid warning onsets -> one playback.
	fm._warning_cooldown_left = 0.0
	fm._haptic_cooldown_left = 0.0
	_check(fm.play_event(&"warning") and not fm.play_event(&"warning"),
		"warning audio obeys its cooldown (no per-frame repetition)")
	_check(audio_ev.count(&"warning") == 1,
		"duplicate warning requests do not double-play")

	# Mute suppresses playback.
	fm.muted = true
	var audio_before_mute: int = audio_ev.size()
	_check(not fm.play_event(&"success") and audio_ev.size() == audio_before_mute,
		"mute suppresses playback requests")
	fm.muted = false

	# Success/failure events through real mission outcomes (legacy layout,
	# default grace restored after the failure-probe section).
	await m6.load_level(LevelCatalog.default_descriptor())
	m6.mission_manager.detection_grace = 3.0
	await _frames(4)
	(m6.player as CharacterBody2D).global_position = Vector2(1224.0, 120.0)
	await _frames(2)
	Input.action_press("interact")
	await _frames(3)
	Input.action_release("interact")
	(m6.player as CharacterBody2D).global_position = Vector2(1128.0, 600.0)
	await _frames(4)
	_check(audio_ev.count(&"success") == 1,
		"mission success routes the success audio event")
	# Failure event via genuine detection.
	var m6_mm: MissionManager = m6.mission_manager
	m6_mm.detection_grace = 0.3
	await m6.restart_mission()
	await _frames(4)
	_mk_main_enemy(m6, Vector2(72.0, 168.0), Vector2(0, -1))
	await _frames(40)
	_check(m6_mm.state == MissionManager.State.FAILED and audio_ev.count(&"failure") == 1,
		"mission failure routes the failure audio event")
	_check(audio_ev.count(&"warning") >= 1 and audio_ev.count(&"warning") <= 2,
		"sustained detection triggers at most onset+critical warnings (%d)" % audio_ev.count(&"warning"))

	# Haptic configuration and cooldown.
	fm.haptics_enabled = false
	fm._haptic_cooldown_left = 0.0
	var haptic_before_disable: int = haptic_ev.size()
	_check(not fm.request_haptic(100) and haptic_ev.size() == haptic_before_disable,
		"disabled haptics suppress requests")
	fm.haptics_enabled = true
	fm._haptic_cooldown_left = 0.0
	var haptic_before: int = haptic_ev.size()
	_check(fm.request_haptic(100) and not fm.request_haptic(100)
		and haptic_ev.size() == haptic_before + 1,
		"haptic requests obey the cooldown and rate limit")

	# Restart: no accumulated listeners, feedback survives.
	var audio_conns: int = fm.audio_played.get_connections().size()
	var obj_conns: int = m6_mm.objective_completed.get_connections().size()
	await m6.restart_mission()
	await _frames(4)
	_check(fm.audio_played.get_connections().size() == audio_conns
		and m6_mm.objective_completed.get_connections().size() == obj_conns
		and fm.get_child_count() == 5,
		"restart leaks no feedback listeners or audio players")

	# Old mission events cannot update the new mission HUD.
	m6_mm.on_terminal_completed(&"ghost_terminal")
	_check(m6_mm.objectives_done() == 0
		and m6.mission_manager.state == MissionManager.State.ACTIVE,
		"stale mission events cannot corrupt the restarted mission")

	# --- P6-T2: detection meter truth ---
	await m6.restart_mission()
	m6_mm.detection_grace = 3.0
	await _frames(4)
	var dm: DetectionMeter = m6.get_node("UI/DetectionMeter")
	_check(dm.target == 0.0 and not dm.suspected,
		"detection meter starts clear on a fresh mission")
	var e6_det: CharacterBody2D = _mk_main_enemy(m6, Vector2(72.0, 168.0), Vector2(0, -1))
	await _frames(25)
	_check(m6_mm.state == MissionManager.State.ACTIVE,
		"detection probe stays inside the grace period (meter semantics)")
	var ratio_mid: float = m6_mm.detection_ratio()
	_check(ratio_mid > 0.0 and absf(dm.target - ratio_mid) < 0.02,
		"detection meter tracks the real mission timer ratio (%.2f)" % dm.target)
	(m6.player as CharacterBody2D).global_position = Vector2(1500.0, 1500.0)
	await _frames(8)
	_check(dm.target == 0.0 and m6_mm.detection_timer == 0.0,
		"breaking line of sight clears the detection danger immediately")

	# Suspicion (noise) never reads as confirmed detection: a fresh enemy
	# facing away, noise only - no visual contact ever happens.
	await m6.restart_mission()
	await _frames(4)
	var e6_noise: CharacterBody2D = _mk_main_enemy(m6, Vector2(72.0, 168.0), Vector2(0, 1))
	(m6.player as CharacterBody2D).global_position = Vector2(72.0, 72.0)
	await _frames(2)
	StealthSystem.publish_noise(Vector2(300.0, 168.0), 300.0, &"player", &"walk")
	await _frames(30)
	_check(dm.target == 0.0 and dm.suspected,
		"suspicion shows as a subtle hint, never as confirmed detection")

	# --- P6-T2: responsive HUD layout at multiple viewport sizes ---
	# Headless limitation: the window is virtual; Control rectangles are
	# real computed layout. Safe-area insets are NOT modeled here
	# (device-only) - documented limitation, not a device claim.
	var touch6: Control = m6.get_node("UI/TouchLayer")
	var hud6: Control = m6.get_node("UI/HUD")
	var meter6: Control = m6.get_node("UI/VisibilityMeter")
	var status6: Control = m6.get_node("UI/Status")
	var all_clear := true
	var detail := ""
	for probe_size: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080), Vector2(960, 540)]:
		var vp_probe: SubViewport = SubViewport.new()
		vp_probe.size = probe_size
		add_child(vp_probe)
		var m7: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
		vp_probe.add_child(m7)
		await _frames(6)
		var touch_p: Control = m7.get_node("UI/TouchLayer")
		var joy_rect: Rect2 = touch_p.joystick_reserved_rect()
		var btn_rect: Rect2 = touch_p.buttons_reserved_rect()
		var ui_nodes: Array[Control] = [m7.get_node("UI/HUD"), m7.get_node("UI/VisibilityMeter"),
			m7.get_node("UI/DetectionMeter"), m7.get_node("UI/Status")]
		for ui_node: Control in ui_nodes:
			var r: Rect2 = ui_node.get_global_rect()
			if r.intersects(joy_rect) or r.intersects(btn_rect) or not (Rect2(Vector2.ZERO, probe_size)).encloses(r):
				all_clear = false
				detail = "%s at %s" % [ui_node.name, probe_size]
		m7.queue_free()
		vp_probe.queue_free()
		await _frames(2)
	_check(all_clear, "HUD stays clear of touch regions inside every tested viewport" + (" (%s)" % detail if detail != "" else ""))
	_check(hud6.text.contains("Obj") and hud6.text.contains("Extract")
		and hud6.text.contains("Zone"),
		"HUD keeps objectives, extraction and zone visible")
	_check(hud6.text.count("\n") == 4 and hud6.text.length() < 200,
		"permanent HUD text stays compact (%d lines)" % [hud6.text.count("\n") + 1])

	# Teardown cleanliness.
	m6.queue_free()
	await _frames(6)
	_check(StealthSystem.light_count() == 0
		and StealthSystem.noise_emitted.get_connections().size() == noise_base6,
		"polish fixture tears down without leaking lights, noise or feedback listeners")

	if failures == 0:
		print("SMOKE TEST: all checks passed")
		get_tree().quit(0)
	else:
		print("SMOKE TEST: %d check(s) FAILED" % failures)
		get_tree().quit(1)


## Instantiates a standalone enemy fixture: standing patrol (single point),
## explicit facing, fast decisions, given a player reference.
## World centers of every marker cell of [param tile] in scan order.
func _all_marker_centers(rows: Array, tile: String) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for y in range(rows.size()):
		var row := rows[y] as String
		var x: int = row.find(tile)
		while x >= 0:
			result.append(Vector2(x + 0.5, y + 0.5) * 48.0)
			x = row.find(tile, x + 1)
	return result


## Fixture enemy owned by a live main scene (registered in its enemy list
## so the mission manager accounts for it).
func _mk_main_enemy(m: Node, at: Vector2, face: Vector2) -> CharacterBody2D:
	var enemy: CharacterBody2D = (load("res://scenes/enemy.tscn") as PackedScene).instantiate()
	m.add_child(enemy)
	enemy.position = at
	enemy.set_player(m.player)
	enemy.set_patrol_route([at])
	enemy.ai_interval = 0.05
	enemy.facing = face
	m.enemies.append(enemy)
	return enemy


## Expected world center of the first marker cell in a grid.
func _marker_center(rows: Array, tile: String) -> Vector2:
	for y in range(rows.size()):
		var x: int = (rows[y] as String).find(tile)
		if x >= 0:
			return Vector2(x + 0.5, y + 0.5) * 48.0
	return Vector2(-9999, -9999)


## The cell center a world position sits on (for spawn validation).
func _marker_center_of(rows: Array, world_pos: Vector2) -> Vector2:
	var cell := Vector2i(int(world_pos.x / 48.0), int(world_pos.y / 48.0))
	return Vector2(cell.x + 0.5, cell.y + 0.5) * 48.0


## All '1' cells of a grid as a Dictionary of Vector2i -> true.
func _expected_lit(rows: Array) -> Dictionary:
	var lit := {}
	for y in range(rows.size()):
		var row := rows[y] as String
		for x in range(row.length()):
			if row[x] == "1":
				lit[Vector2i(x, y)] = true
	return lit


func _same_keys(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key in a:
		if not b.has(key):
			return false
	return true


func _mk_enemy(p: CharacterBody2D, at: Vector2, face: Vector2) -> CharacterBody2D:
	var enemy: CharacterBody2D = (load("res://scenes/enemy.tscn") as PackedScene).instantiate()
	enemy.position = at
	add_child(enemy)
	enemy.set_player(p)
	enemy.set_patrol_route([at])
	enemy.ai_interval = 0.05
	enemy.facing = face
	return enemy


## Awaits (bounded) until the enemy reaches the given state.
func _await_state(enemy: CharacterBody2D, wanted: StringName, max_frames: int) -> bool:
	for i in range(max_frames):
		if enemy.state == wanted:
			return true
		await get_tree().physics_frame
	return enemy.state == wanted


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _on_noise_event(event: NoiseEvent) -> void:
	_noise_events.append(event)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("  PASS: %s" % description)
	else:
		failures += 1
		print("  FAIL: %s" % description)
