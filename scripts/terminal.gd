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

const COLOR_AVAILABLE := Color(0.95, 0.75, 0.2)
const COLOR_COMPLETED := Color(0.2, 0.75, 0.35)

var terminal_id: StringName = &"terminal_1"
var state: int = State.AVAILABLE
var size_px: float = 36.0


func _ready() -> void:
	# Visual marker only - no collision body (interaction uses distance
	# plus a physics line-of-sight ray, see Main._los_clear_to).
	var visual := Polygon2D.new()
	visual.name = "Visual"
	var h: float = size_px / 2.0
	visual.polygon = PackedVector2Array([
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)
	])
	visual.color = COLOR_AVAILABLE
	add_child(visual)


## Attempts completion. Returns false (and emits nothing) if this
## terminal is already completed - duplicate reward prevention.
func complete() -> bool:
	if state == State.COMPLETED:
		return false
	state = State.COMPLETED
	var visual := get_node_or_null("Visual") as Polygon2D
	if visual != null:
		visual.color = COLOR_COMPLETED
	completed.emit(terminal_id)
	return true


func is_completed() -> bool:
	return state == State.COMPLETED
