class_name Terminal
extends Node2D
## Shadow Protocol - mission terminal (Phase 5, tile '3').
##
## An interactive objective object created by the level generator at the
## '3' cell center. Phase 5 completion model: immediate validated
## interaction (no hacking minigame - the roadmap defines none).
##
## States:
##   AVAILABLE - can be completed once
##   COMPLETED - finished; further completions are rejected
##
## terminal_id is assigned deterministically in grid scan order
## ("terminal_N"), stable within a level. The completed signal carries
## the stable id; MissionManager counts each id exactly once.

signal completed(terminal_id: StringName)

enum State { AVAILABLE, COMPLETED }

const COLOR_AVAILABLE := Color(0.98, 0.72, 0.28)
const COLOR_COMPLETED := Color(0.32, 0.85, 0.45)
const COLOR_CONSOLE := Color(0.12, 0.145, 0.19)
const COLOR_CONSOLE_EDGE := Color(0.30, 0.36, 0.45)
const COLOR_HIGHLIGHT := Color(1.0, 0.82, 0.40)
## In-interaction-range highlight flag (set by Main from its existing
## nearest-target logic; presentation only).
var highlighted: bool = false

var terminal_id: StringName = &"terminal_1"
var state: int = State.AVAILABLE
var size_px: float = 36.0


func _ready() -> void:
	# Visual marker only - no collision body (interaction uses distance
	# plus a physics line-of-sight ray, see Main._los_clear_to).
	# Console rig: outer housing, status screen, LED. The screen carries
	# the state color; the housing stays a constant dark structure.
	var h: float = size_px / 2.0
	var housing := Polygon2D.new()
	housing.name = "Housing"
	housing.polygon = PackedVector2Array([
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)
	])
	housing.color = COLOR_CONSOLE
	add_child(housing)
	var edge := Line2D.new()
	edge.name = "Edge"
	edge.width = 1.5
	edge.closed = true
	edge.default_color = COLOR_CONSOLE_EDGE
	edge.points = PackedVector2Array([
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	add_child(edge)
	var screen := Polygon2D.new()
	screen.name = "Screen"
	var sh: float = h - 6.0
	screen.polygon = PackedVector2Array([
		Vector2(-sh, -sh * 0.7), Vector2(sh, -sh * 0.7),
		Vector2(sh, sh * 0.55), Vector2(-sh, sh * 0.55)
	])
	screen.color = COLOR_AVAILABLE
	add_child(screen)
	var led := Polygon2D.new()
	led.name = "Led"
	led.polygon = _circle_pts(2.5, 10)
	led.position = Vector2(0.0, h - 6.0)
	led.color = COLOR_AVAILABLE
	add_child(led)


func _circle_pts(radius: float, points: int) -> PackedVector2Array:
	var array := PackedVector2Array()
	for i in range(points):
		var angle: float = TAU * i / points
		array.append(Vector2(cos(angle), sin(angle)) * radius)
	return array


## Presentation-only range highlight (Main owns the real nearest-target
## decision). No gameplay state changes.
func set_highlight(active: bool) -> void:
	if highlighted == active:
		return
	highlighted = active
	_apply_visual()


func _apply_visual() -> void:
	var screen := get_node_or_null("Screen") as Polygon2D
	var led := get_node_or_null("Led") as Polygon2D
	var edge := get_node_or_null("Edge") as Line2D
	if screen == null or led == null:
		return
	if state == State.COMPLETED:
		screen.color = COLOR_COMPLETED
		led.color = COLOR_COMPLETED
		if edge != null:
			edge.default_color = Color(0.32, 0.85, 0.45, 0.55)
		return
	if highlighted:
		screen.color = COLOR_HIGHLIGHT
		led.color = COLOR_HIGHLIGHT
		if edge != null:
			edge.default_color = Color(1.0, 0.82, 0.40, 0.85)
	else:
		screen.color = COLOR_AVAILABLE
		led.color = COLOR_AVAILABLE
		if edge != null:
			edge.default_color = COLOR_CONSOLE_EDGE


## Attempts completion. Returns false (and emits nothing) if this
## terminal is already completed - duplicate reward prevention.
func complete() -> bool:
	if state == State.COMPLETED:
		return false
	state = State.COMPLETED
	_apply_visual()
	completed.emit(terminal_id)
	return true


func is_completed() -> bool:
	return state == State.COMPLETED
