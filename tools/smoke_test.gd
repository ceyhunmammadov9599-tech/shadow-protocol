extends Node
## Shadow Protocol - headless smoke test scene.
##
## Runs inside the real engine loop (physics spaces active, autoloads
## loaded) and verifies Phase 1 acceptance criteria that are testable
## without a touchscreen: movement acceleration, crouch speed, sprint,
## friction/stop, joystick dead zone and saturation math, visibility and
## noise model values.
##
## Run with:
##   godot --headless --path . res://tools/smoke_test.tscn
## Exit code 0 = all checks passed.

var failures: int = 0


func _ready() -> void:
	var player: CharacterBody2D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	add_child(player)
	player.position = Vector2(240, 240)
	await _frames(3)  # let physics spaces register

	# --- Keyboard movement: acceleration toward WALK_SPEED ---
	Input.action_press("move_right")
	await _frames(60)
	var walk_speed: float = player.velocity.length()
	_check(walk_speed > 200.0 and walk_speed <= 240.0, "walk speed in (200, 240], got %.1f" % walk_speed)
	Input.action_release("move_right")

	# --- Crouch: slows down to CROUCH_SPEED ---
	Input.action_press("crouch")
	Input.action_press("move_right")
	await _frames(120)
	_check(player.crouching, "crouching flag set")
	var crouch_speed: float = player.velocity.length()
	_check(crouch_speed > 90.0 and crouch_speed <= 110.0, "crouch speed in (90, 110], got %.1f" % crouch_speed)
	Input.action_release("move_right")
	Input.action_release("crouch")

	# --- Friction: decelerates to a stop ---
	await _frames(120)
	_check(player.velocity.length() < 1.0, "stops after friction, got %.2f" % player.velocity.length())

	# --- Sprint: exceeds walk speed ---
	Input.action_press("move_right")
	Input.action_press("sprint")
	await _frames(120)
	_check(player.sprinting and player.velocity.length() > 240.0,
		"sprint exceeds walk speed, got %.1f" % player.velocity.length())
	Input.action_release("move_right")
	Input.action_release("sprint")

	# --- Touch joystick: dead zone and saturation ---
	var touch: Control = load("res://scripts/mobile_controls.gd").new()
	add_child(touch)
	touch._joystick_index = 0
	touch._joystick_origin = Vector2(200, 200)
	touch._update_joystick(Vector2(210, 200))  # 10px: below dead zone
	_check(touch.get_movement_vector() == Vector2.ZERO, "dead zone zeroes tiny drags")
	touch._update_joystick(Vector2(310, 200))  # 110px: full saturation
	var full: Vector2 = touch.get_movement_vector()
	_check(absf(full.x - 1.0) < 0.001 and absf(full.y) < 0.001,
		"full drag saturates to unit vector, got %s" % full)
	touch._update_joystick(Vector2(255, 200))  # half range: partial intensity
	var half: Vector2 = touch.get_movement_vector()
	_check(half.x > 0.2 and half.x < 0.9, "mid drag gives partial intensity, got %s" % half)
	touch._handle_release(0)
	_check(touch.get_movement_vector() == Vector2.ZERO, "release returns to neutral")

	# --- StealthSystem autoload: visibility and noise model ---
	var stealth: Node = get_node("/root/StealthSystem")
	stealth.configure({Vector2i(5, 5): true}, 48.0, Vector2.ZERO)
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

	player.queue_free()
	touch.queue_free()

	if failures == 0:
		print("SMOKE TEST: all checks passed")
		get_tree().quit(0)
	else:
		print("SMOKE TEST: %d check(s) FAILED" % failures)
		get_tree().quit(1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("  PASS: %s" % description)
	else:
		failures += 1
		print("  FAIL: %s" % description)
