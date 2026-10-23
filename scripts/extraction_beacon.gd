class_name ExtractionBeacon
extends Node2D
## Shadow Protocol - extraction point presentation (visual upgrade).
##
## A distinct beacon instead of a flat circle marker. Three visual states,
## all driven by real mission state via set_active()/set_completed():
##   LOCKED  - dim green outline (objective not yet met)
##   ACTIVE  - bright green ring with a slow pulse (extraction available)
##   DONE    - bright static green (mission succeeded)
## The pulse is the only continuous animation and runs ONLY while ACTIVE;
## a locked beacon costs zero per-frame work.

const COLOR_LOCKED := Color(0.28, 0.45, 0.34)
const COLOR_ACTIVE := Color(0.32, 0.85, 0.45)
const COLOR_DONE := Color(0.45, 0.95, 0.55)

enum VisState { LOCKED, ACTIVE, DONE }

var vis_state: int = VisState.LOCKED
var _pulse_phase: float = 0.0
var _radius: float = 14.0


func set_active(active: bool) -> void:
	if vis_state == VisState.DONE:
		return  # completed is terminal until the next level load
	vis_state = VisState.ACTIVE if active else VisState.LOCKED
	_apply()


func set_completed() -> void:
	vis_state = VisState.DONE
	_apply()


func is_active() -> bool:
	return vis_state == VisState.ACTIVE


func _ready() -> void:
	_apply()


func _apply() -> void:
	match vis_state:
		VisState.LOCKED:
			modulate = Color(0.65, 0.75, 0.7)
		VisState.ACTIVE:
			modulate = Color.WHITE
		VisState.DONE:
			modulate = Color.WHITE
	queue_redraw()


func _process(delta: float) -> void:
	# Slow, restrained pulse ONLY in the ACTIVE state.
	if vis_state != VisState.ACTIVE:
		if _pulse_phase != 0.0:
			_pulse_phase = 0.0
			queue_redraw()
		return
	_pulse_phase = fmod(_pulse_phase + delta, 2.0)
	queue_redraw()


func _draw() -> void:
	var color: Color = COLOR_LOCKED
	if vis_state == VisState.ACTIVE:
		color = COLOR_ACTIVE
	elif vis_state == VisState.DONE:
		color = COLOR_DONE
	var alpha_boost: float = 1.0
	if vis_state == VisState.ACTIVE:
		alpha_boost = 0.75 + 0.25 * sin(_pulse_phase * PI)
	# Outer ring.
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 32, Color(color.r, color.g, color.b, 0.9 * alpha_boost), 2.0)
	# Inner chevron (upward - "get out" cue).
	var chev := PackedVector2Array([
		Vector2(0, -5.0), Vector2(5.5, 2.5), Vector2(2.5, 2.5),
		Vector2(0, -1.5), Vector2(-2.5, 2.5), Vector2(-5.5, 2.5)])
	draw_colored_polygon(chev, Color(color.r, color.g, color.b, 0.95 * alpha_boost))
	# Soft ground glow.
	draw_circle(Vector2.ZERO, _radius + 8.0, Color(color.r, color.g, color.b, 0.08 * alpha_boost))
