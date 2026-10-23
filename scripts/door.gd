class_name Door
extends StaticBody2D
## Shadow Protocol - door (Phase 4, tile '7').
##
## A door occupies one grid cell. States:
##   closed (default) - collision shape enabled: blocks player/enemy
##                      movement AND enemy vision raycasts (its
##                      StaticBody2D is on collision layer 1, so Phase 3
##                      raycast obstruction works automatically)
##   open             - collision shape disabled: movement and vision pass
## State transitions are deterministic and testable; StealthSystem
## subscribes to state_changed so navigation queries (is_cell_blocked)
## update live. Doors never permanently obstruct progression: they are
## player-openable (full interaction arrives in Phase 5).

signal state_changed(is_open: bool)

const COLOR_CLOSED := Color(0.55, 0.38, 0.22)
const COLOR_OPEN := Color(0.30, 0.42, 0.30)

var is_open: bool = false
var cell: Vector2i = Vector2i(-1, -1)
var size_px: float = 48.0


func _ready() -> void:
	# Collision body fills the door cell (slight inset to avoid edge
	# catching on adjacent wall bodies).
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(size_px - 4.0, size_px - 4.0)
	shape.shape = rect
	add_child(shape)

	var visual := Polygon2D.new()
	visual.name = "Visual"
	visual.polygon = PackedVector2Array([
		Vector2(-size_px / 2.0 + 2.0, -size_px / 2.0 + 2.0),
		Vector2(size_px / 2.0 - 2.0, -size_px / 2.0 + 2.0),
		Vector2(size_px / 2.0 - 2.0, size_px / 2.0 - 2.0),
		Vector2(-size_px / 2.0 + 2.0, size_px / 2.0 - 2.0),
	])
	visual.color = COLOR_CLOSED
	add_child(visual)
	_apply_state()


func set_state(open: bool) -> void:
	if open == is_open:
		return
	is_open = open
	_apply_state()
	state_changed.emit(is_open)


func toggle() -> void:
	set_state(not is_open)


func _apply_state() -> void:
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null:
		shape.disabled = is_open
	var visual := get_node_or_null("Visual") as Polygon2D
	if visual != null:
		visual.color = COLOR_OPEN if is_open else COLOR_CLOSED
