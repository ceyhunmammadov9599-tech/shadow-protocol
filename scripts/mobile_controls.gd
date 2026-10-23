extends Control
## Shadow Protocol - native-feeling multi-touch controls.
##
## Left half of the screen: floating analog joystick (base appears where
## the finger lands, follows long drags, dead-zone handled, auto-centers).
## Right side: circular action buttons for CROUCH (toggle), SPRINT (toggle)
## and INTERACT (press). Every touch is tracked by pointer index so the
## joystick and buttons never interfere with each other.
##
## Keyboard users are unaffected: the layer hides itself when no
## touchscreen is available and the player falls back to InputMap actions.

signal crouch_toggled(active: bool)
signal sprint_toggled(active: bool)
signal interact_pressed()

const JOYSTICK_MAX_RADIUS: float = 110.0
const JOYSTICK_DEAD_ZONE: float = 0.15
const JOYSTICK_ZONE_WIDTH_RATIO: float = 0.45
const BUTTON_RADIUS: float = 42.0
const INTERACT_RADIUS: float = 52.0

const COLOR_BASE := Color(1, 1, 1, 0.08)
const COLOR_RING := Color(1, 1, 1, 0.25)
const COLOR_KNOB := Color(0.24, 0.78, 0.85, 0.9)
const COLOR_BTN := Color(1, 1, 1, 0.07)
const COLOR_BTN_PRESSED := Color(0.24, 0.78, 0.85, 0.35)
const COLOR_BTN_TEXT := Color(0.85, 0.88, 0.92, 0.9)

var _joystick_index: int = -1
var _joystick_origin: Vector2 = Vector2.ZERO
var _joystick_vector: Vector2 = Vector2.ZERO
var _joystick_visible: bool = false
var _buttons: Dictionary = {}
var _button_touches: Dictionary = {}  # pointer index -> button name
var _crouch_active: bool = false
var _sprint_active: bool = false


## Reserved gameplay region of the floating joystick (left 45% of the
## screen, below mid-height where thumbs operate it). HUD must stay
## out of this rectangle. Shared truth for layout and layout tests.
func joystick_reserved_rect() -> Rect2:
	var screen: Vector2 = get_viewport_rect().size
	return Rect2(Vector2(0.0, screen.y * 0.45), Vector2(screen.x * 0.45, screen.y * 0.55))

## Reserved region of the action buttons (bottom-right cluster).
func buttons_reserved_rect() -> Rect2:
	var screen: Vector2 = get_viewport_rect().size
	return Rect2(screen - Vector2(340.0, 340.0), Vector2(340.0, 340.0))

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchors_preset = Control.PRESET_FULL_RECT
	# Only show the touch overlay on real touch devices (Android, touchscreens).
	# The explicit touch_debug project setting (shadow_protocol/touch_debug,
	# default false) forces the overlay for desktop layout testing; it is
	# read once here so toggling it takes effect on the next scene load.
	visible = DisplayServer.is_touchscreen_available() \
		or OS.has_feature("android") \
		or ProjectSettings.get_setting("shadow_protocol/touch_debug", false)
	_layout_buttons()
	get_viewport().size_changed.connect(_layout_buttons)


func _layout_buttons() -> void:
	var screen: Vector2 = get_viewport_rect().size
	_buttons = {
		"interact": {
			"center": Vector2(screen.x - 110.0, screen.y - 120.0),
			"radius": INTERACT_RADIUS,
			"label": "ACT",
			"pressed": false,
		},
		"crouch": {
			"center": Vector2(screen.x - 226.0, screen.y - 76.0),
			"radius": BUTTON_RADIUS,
			"label": "CRCH",
			"pressed": false,
		},
		"sprint": {
			"center": Vector2(screen.x - 196.0, screen.y - 192.0),
			"radius": BUTTON_RADIUS,
			"label": "SPRNT",
			"pressed": false,
		},
	}
	# Toggle buttons keep their active state across relayouts.
	_buttons["crouch"]["pressed"] = _crouch_active
	_buttons["sprint"]["pressed"] = _sprint_active
	queue_redraw()


## Current analog movement vector, magnitude in 0..1 (dead zone applied).
func get_movement_vector() -> Vector2:
	return _joystick_vector


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_handle_press(event.position, event.index)
		else:
			_handle_release(event.index)
	elif event is InputEventScreenDrag and event.index == _joystick_index:
		_update_joystick(event.position)


func _handle_press(pos: Vector2, index: int) -> void:
	# Buttons win over the joystick zone if the touch lands on one.
	for name: String in _buttons:
		var btn: Dictionary = _buttons[name]
		if pos.distance_to(btn["center"]) <= btn["radius"]:
			_button_touches[index] = name
			_press_button(name)
			return
	var zone_width: float = get_viewport_rect().size.x * JOYSTICK_ZONE_WIDTH_RATIO
	if pos.x <= zone_width:
		_joystick_index = index
		_joystick_origin = pos
		_joystick_vector = Vector2.ZERO
		_joystick_visible = true
		queue_redraw()


func _handle_release(index: int) -> void:
	if index == _joystick_index:
		_joystick_index = -1
		_joystick_vector = Vector2.ZERO
		_joystick_visible = false
		queue_redraw()
	elif _button_touches.has(index):
		var name: String = _button_touches[index]
		_button_touches.erase(index)
		# Toggles keep their latched state; momentary buttons reset.
		if name == "interact":
			_buttons[name]["pressed"] = false
		queue_redraw()


func _update_joystick(pos: Vector2) -> void:
	var offset: Vector2 = pos - _joystick_origin
	var distance: float = offset.length()
	if distance > JOYSTICK_MAX_RADIUS:
		# Base follows the finger on long drags ("floating" joystick).
		_joystick_origin += offset - offset.normalized() * JOYSTICK_MAX_RADIUS
		offset = offset.normalized() * JOYSTICK_MAX_RADIUS
	var normalized: Vector2 = offset / JOYSTICK_MAX_RADIUS
	var magnitude: float = normalized.length()
	if magnitude < JOYSTICK_DEAD_ZONE:
		_joystick_vector = Vector2.ZERO
	else:
		# Rescale above the dead zone so low magnitudes are not lost.
		var scaled: float = (magnitude - JOYSTICK_DEAD_ZONE) / (1.0 - JOYSTICK_DEAD_ZONE)
		_joystick_vector = normalized.normalized() * scaled
	queue_redraw()


func _press_button(name: String) -> void:
	match name:
		"interact":
			_buttons[name]["pressed"] = true
			interact_pressed.emit()
		"crouch":
			_crouch_active = not _crouch_active
			_buttons[name]["pressed"] = _crouch_active
			crouch_toggled.emit(_crouch_active)
		"sprint":
			_sprint_active = not _sprint_active
			_buttons[name]["pressed"] = _sprint_active
			sprint_toggled.emit(_sprint_active)
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	if _joystick_visible:
		draw_circle(_joystick_origin, JOYSTICK_MAX_RADIUS * 0.55, COLOR_BASE)
		draw_arc(_joystick_origin, JOYSTICK_MAX_RADIUS * 0.55, 0.0, TAU, 40, COLOR_RING, 2.0)
		var knob: Vector2 = _joystick_origin + _joystick_vector * JOYSTICK_MAX_RADIUS * 0.55
		draw_circle(knob, 26.0, COLOR_KNOB)
	for name: String in _buttons:
		var btn: Dictionary = _buttons[name]
		var fill: Color = COLOR_BTN_PRESSED if btn["pressed"] else COLOR_BTN
		draw_circle(btn["center"], btn["radius"], fill)
		draw_arc(btn["center"], btn["radius"], 0.0, TAU, 40, COLOR_RING, 2.0)
		draw_string(
			ThemeDB.fallback_font,
			btn["center"] + Vector2(-24.0, 8.0),
			btn["label"],
			HORIZONTAL_ALIGNMENT_CENTER,
			48.0,
			14,
			COLOR_BTN_TEXT
		)
