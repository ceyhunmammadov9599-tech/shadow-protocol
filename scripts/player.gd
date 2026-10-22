extends CharacterBody2D
## Shadow Protocol - player controller.
##
## Top-down tactical movement with analog joystick / keyboard input,
## acceleration and friction, crouch and sprint states, and clean
## interfaces for the stealth systems (visibility, noise, interaction).

signal noise_emitted(pos: Vector2, radius: float)
signal visibility_updated(value: float)
signal interact_requested()

## Movement tuning (pixels per second).
const WALK_SPEED: float = 240.0
const CROUCH_SPEED: float = 105.0
const SPRINT_MULTIPLIER: float = 1.45
const ACCELERATION: float = 12.0
const FRICTION: float = 10.0

## Stealth interface values (consumed by enemy AI in Phase 3).
const NOISE_INTERVAL: float = 0.25
const NOISE_RADIUS_CROUCHED: float = 90.0
const NOISE_RADIUS_WALKING: float = 220.0
const NOISE_RADIUS_SPRINT: float = 320.0

## Runtime state.
var move_input: Vector2 = Vector2.ZERO
var crouching: bool = false
var sprinting: bool = false
var visibility: float = 0.0
var speed_ratio: float = 0.0

var _touch_crouch: bool = false
var _touch_sprint: bool = false
var _touch_controls: Control = null
var _noise_timer: float = 0.0

@onready var visual: Polygon2D = $Visual
@onready var camera: Camera2D = $Camera2D

const COLOR_STANDING := Color(0.24, 0.78, 0.85)
const COLOR_CROUCHED := Color(0.16, 0.52, 0.58)


func _ready() -> void:
	# Defensive: the scene always provides these, but keep the controller
	# usable in isolation (unit scenes, future test harnesses).
	if visual == null:
		push_warning("player.gd: Visual node missing")


func set_touch_controls(controls: Control) -> void:
	_touch_controls = controls


func set_touch_crouch(active: bool) -> void:
	_touch_crouch = active


func set_touch_sprint(active: bool) -> void:
	_touch_sprint = active


func _physics_process(delta: float) -> void:
	move_input = _read_move_input()
	var keyboard_crouch: bool = Input.is_action_pressed("crouch")
	var keyboard_sprint: bool = Input.is_action_pressed("sprint")
	crouching = _touch_crouch or keyboard_crouch
	sprinting = (_touch_sprint or keyboard_sprint) and not crouching

	var max_speed: float = CROUCH_SPEED if crouching else WALK_SPEED
	if sprinting:
		max_speed *= SPRINT_MULTIPLIER

	var desired_velocity: Vector2 = move_input * max_speed
	var lerp_weight: float = ACCELERATION if move_input.length_squared() > 0.001 else FRICTION
	velocity = velocity.lerp(desired_velocity, clampf(lerp_weight * delta, 0.0, 1.0))
	move_and_slide()

	speed_ratio = clampf(velocity.length() / (WALK_SPEED * SPRINT_MULTIPLIER), 0.0, 1.0)
	_update_noise(delta)
	_update_visual_state()


## Touch joystick first (when present and active), keyboard action map as
## fallback. This is the explicit integration point between the custom
## touchscreen layer and the engine InputMap.
func _read_move_input() -> Vector2:
	if _touch_controls != null and is_instance_valid(_touch_controls):
		var joy: Vector2 = _touch_controls.get_movement_vector()
		if joy.length_squared() > 0.0:
			return joy
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


## Emits movement noise at a fixed cadence while the player is moving.
## Enemies subscribe to [signal noise_emitted] in Phase 3.
func _update_noise(delta: float) -> void:
	if velocity.length() < 10.0:
		_noise_timer = 0.0
		return
	_noise_timer += delta
	if _noise_timer >= NOISE_INTERVAL:
		_noise_timer = 0.0
		noise_emitted.emit(global_position, _current_noise_radius())


func _current_noise_radius() -> float:
	if crouching:
		return NOISE_RADIUS_CROUCHED
	if sprinting:
		return NOISE_RADIUS_SPRINT
	return NOISE_RADIUS_WALKING * (0.55 + 0.45 * speed_ratio)


## Visibility is computed externally by StealthSystem and pushed in here,
## keeping the controller decoupled from lighting data.
func set_visibility(value: float) -> void:
	visibility = clampf(value, 0.0, 1.0)
	visibility_updated.emit(visibility)


func request_interact() -> void:
	interact_requested.emit()


func _update_visual_state() -> void:
	if visual == null:
		return
	var target_scale: float = 0.75 if crouching else 1.0
	visual.scale = visual.scale.lerp(Vector2.ONE * target_scale, 0.2)
	visual.color = COLOR_CROUCHED if crouching else COLOR_STANDING
