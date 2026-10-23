class_name DetectionMeter
extends Control
## Shadow Protocol - mission detection danger meter (Phase 6, P6-T2).
##
## Distinct from VisibilityMeter by design:
## - VisibilityMeter shows environmental EXPOSURE (StealthSystem 0..1).
## - DetectionMeter shows the mission-failure risk from CONFIRMED enemy
##   visual contact: the MissionManager detection timer ratio
##   (detection_timer / detection_grace). It rises only while an enemy
##   genuinely sees the player and drops the moment contact ends (the
##   mission manager's documented reset rule).
##
## Display states (kept distinct; color is never the only signal - a
## text state caption always accompanies the bar):
## - UNDETECTED: ratio 0, no suspicion (dark track).
## - SUSPECTED: ratio 0 but enemies are suspicious/investigating -
##   a subtle amber text hint only, never a detection alarm.
## - DETECTED: ratio > 0, amber/red bar with percentage.
## - CRITICAL: ratio >= 0.5 of the grace period, red bar - imminent
##   mission failure risk.
##
## Anchored top-center below the visibility meter, away from the
## joystick and action buttons.

const SMOOTH_SPEED: float = 6.0
const CRITICAL_AT: float = 0.5

const COLOR_TRACK := Color(1, 1, 1, 0.10)
const COLOR_DETECTED := Color(0.95, 0.62, 0.22)
const COLOR_CRITICAL := Color(0.92, 0.28, 0.28)
const COLOR_TEXT := Color(0.88, 0.90, 0.94)
const COLOR_SUSPECT := Color(0.85, 0.70, 0.35)

## Detection ratio pushed by Main (real MissionManager values).
var target: float = 0.0
## Filtered display value (no flicker).
var display: float = 0.0
## True when enemies are suspicious/investigating WITHOUT confirmed
## visual contact (ordinary suspicion - never shown as detection).
var suspected: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(240.0, 22.0)


func set_value(value: float) -> void:
	target = clampf(value, 0.0, 1.0)


func set_suspected(active: bool) -> void:
	if suspected != active:
		suspected = active
		queue_redraw()


func _process(delta: float) -> void:
	var new_display: float = lerpf(display, target, clampf(delta * SMOOTH_SPEED, 0.0, 1.0))
	if absf(new_display - display) > 0.0005:
		display = new_display
		queue_redraw()
	if suspected:
		# Subtle text hint only; re-draw when suspicion state changes
		# are handled by set_suspected.
		pass


func state_caption() -> String:
	if display > 0.0:
		var pct: int = roundi(display * 100.0)
		if display >= CRITICAL_AT:
			return "DETECTION CRITICAL %d%%" % pct
		return "DETECTED %d%%" % pct
	if suspected:
		return "SUSPECTED"
	return "UNDETECTED"


func _draw() -> void:
	var size: Vector2 = get_size()
	var text_height: float = 16.0
	var bar_height: float = size.y - text_height - 4.0

	draw_rect(Rect2(0, 0, size.x, bar_height), COLOR_TRACK)
	var fill_color: Color = COLOR_CRITICAL if display >= CRITICAL_AT else COLOR_DETECTED
	draw_rect(Rect2(0, 0, size.x * display, bar_height), fill_color)

	var caption: String = state_caption()
	var caption_color: Color = COLOR_SUSPECT if (suspected and display == 0.0) else COLOR_TEXT
	draw_string(ThemeDB.fallback_font, Vector2(2.0, bar_height + 15.0), caption,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, caption_color)
	draw_line(Vector2(0, bar_height + 2.0), Vector2(size.x, bar_height + 2.0),
		Color(1, 1, 1, 0.06), 1.0)
