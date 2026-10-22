extends Control
## Shadow Protocol - gameplay visibility meter (Phase 2 UI).
##
## Displays the live visibility coefficient computed by StealthSystem
## (pushed in via set_value()). Three bands, low / medium / high, with a
## smooth display filter so values do not flicker. Drawn procedurally:
## no textures, mobile-cheap, anchored top-center so it never overlaps
## the joystick zone (left) or the action buttons (right).

const SMOOTH_SPEED: float = 5.0

const COLOR_TRACK := Color(1, 1, 1, 0.10)
const COLOR_LOW := Color(0.30, 0.85, 0.45)
const COLOR_MEDIUM := Color(0.95, 0.75, 0.25)
const COLOR_HIGH := Color(0.92, 0.32, 0.32)
const COLOR_TEXT := Color(0.88, 0.90, 0.94)

const LOW_MAX: float = 0.34
const HIGH_MIN: float = 0.67

## Value the stealth system currently reports (0..1).
var target: float = 0.0
## Filtered value actually displayed (smoothed).
var display: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(240.0, 22.0)


func set_value(value: float) -> void:
	target = clampf(value, 0.0, 1.0)


func _process(delta: float) -> void:
	# Critically-damped-ish smoothing: no flicker, still responsive.
	var new_display: float = lerpf(display, target, clampf(delta * SMOOTH_SPEED, 0.0, 1.0))
	if absf(new_display - display) > 0.0005:
		display = new_display
		queue_redraw()


func current_color() -> Color:
	if display < LOW_MAX:
		return COLOR_LOW
	if display < HIGH_MIN:
		return COLOR_MEDIUM
	return COLOR_HIGH


func _draw() -> void:
	var size: Vector2 = get_size()
	var height: float = size.y
	var text_height: float = 16.0
	var bar_height: float = height - text_height - 4.0

	# Track (background) and low/med/high band hints.
	draw_rect(Rect2(0, 0, size.x, bar_height), COLOR_TRACK)
	for band_x: float in [size.x * LOW_MAX, size.x * HIGH_MIN]:
		draw_line(Vector2(band_x, 0), Vector2(band_x, bar_height),
			Color(1, 1, 1, 0.18), 1.0)

	# Fill with the band color of the current value.
	draw_rect(Rect2(0, 0, size.x * display, bar_height), current_color())

	# Percentage caption.
	var label: String = "VISIBILITY %d%%" % [roundi(display * 100.0)]
	draw_string(ThemeDB.fallback_font, Vector2(2.0, bar_height + 15.0), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COLOR_TEXT)
