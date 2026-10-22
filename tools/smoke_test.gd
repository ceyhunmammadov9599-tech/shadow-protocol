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
	await _frames(5)  # level generated, lights spawned, meter driven
	_check(stealth.light_count() == 5, "main scene registers 4 static + 1 moving light, got %d" % stealth.light_count())

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

	if failures == 0:
		print("SMOKE TEST: all checks passed")
		get_tree().quit(0)
	else:
		print("SMOKE TEST: %d check(s) FAILED" % failures)
		get_tree().quit(1)


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
