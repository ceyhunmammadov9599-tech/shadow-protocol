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

const COLOR_CLOSED := Color(0.42, 0.36, 0.30)
const COLOR_OPEN := Color(0.24, 0.42, 0.30)
const COLOR_EDGE_CLOSED := Color(0.85, 0.45, 0.25)
const COLOR_EDGE_OPEN := Color(0.40, 0.85, 0.50)
const COLOR_FRAME := Color(0.32, 0.38, 0.47)
var _panel_tween: Tween = null

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

	# Doorframe: static structure outline on the cell border.
	var frame := Line2D.new()
	frame.name = "Frame"
	frame.width = 2.0
	frame.closed = true
	frame.default_color = COLOR_FRAME
	var f: float = size_px / 2.0
	frame.points = PackedVector2Array([
		Vector2(-f, -f), Vector2(f, -f), Vector2(f, f), Vector2(-f, f),
	])
	add_child(frame)
	# Sliding panel: retracts toward the hinge on open. "Visual" keeps its
	# historical node name; collision stays driven by _apply_state below.
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
	var edge := Line2D.new()
	edge.name = "Edge"
	edge.width = 3.0
	edge.default_color = COLOR_EDGE_CLOSED
	edge.points = PackedVector2Array([
		Vector2(size_px / 2.0 - 2.0, -size_px / 2.0 + 2.0),
		Vector2(size_px / 2.0 - 2.0, size_px / 2.0 - 2.0),
	])
	add_child(edge)
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
		var edge := get_node_or_null("Edge") as Line2D
		if edge != null:
			edge.default_color = COLOR_EDGE_OPEN if is_open \
				else COLOR_EDGE_CLOSED
		# Restrained slide: panel retracts to 12% width toward the hinge.
		# One short tween, killed on re-entry so repeated toggles never
		# stack tweens (no leaks across reloads - scene frees them).
		if _panel_tween != null:
			_panel_tween.kill()
			_panel_tween = null
		_panel_tween = create_tween()
		_panel_tween.tween_property(visual, "scale:x",
			0.12 if is_open else 1.0, 0.12).from(visual.scale.x)
		_panel_tween.parallel().tween_property(visual, "position:x",
			-18.0 if is_open else 0.0, 0.12).from(visual.position.x)
