extends Node2D
## Shadow Protocol - procedural level construction from a text grid.
##
## Grid values (central encoding defined in level_catalog.gd):
##   0 shadow floor  1 illuminated floor  2 solid wall
##   3 mission terminal  4 player spawn  5 enemy spawn  6 extraction point
##   7 door (Door node, closed by default; not a wall - see door.gd)
##
## Walls are merged into horizontal runs (one StaticBody2D per run) to keep
## the node count low. Doors become Door bodies whose collision and vision
## behavior follow their open/closed state. Returns a level descriptor
## consumed by Main and the StealthSystem autoload.

const CELL_SIZE: float = 48.0

const COLOR_MAP := Color(0.07, 0.09, 0.12)
const COLOR_LIT := Color(0.99, 0.86, 0.55, 0.16)
const COLOR_WALL := Color(0.17, 0.20, 0.26)
const COLOR_WALL_EDGE := Color(0.10, 0.12, 0.16)
const COLOR_TERMINAL := Color(0.85, 0.66, 0.20)
const COLOR_EXTRACTION := Color(0.35, 0.85, 0.45)
const COLOR_SPAWN_MARK := Color(0.45, 0.55, 0.65, 0.5)

var grid_size: Vector2i = Vector2i.ZERO


## Builds the level described by [param rows] and returns a descriptor:
##   spawn, terminals (Array), extraction, enemy_spawns (Array),
##   lit_cells (Dictionary of Vector2i), wall_cells (Dictionary of
##   Vector2i), bounds (Rect2), grid_size (Vector2i), cell_size (float),
##   origin (Vector2), zones (Array, passed through), doors (Array of Door),
##   door_cells (Dictionary of Vector2i)
func generate(rows: Array, zones: Array = []) -> Dictionary:
	for child in get_children():
		child.queue_free()

	var height: int = rows.size()
	var width: int = (rows[0] as String).length()
	for i in range(height):
		if (rows[i] as String).length() != width:
			push_error("level_generator: ragged grid row %d" % i)
			width = maxi(width, (rows[i] as String).length())
	grid_size = Vector2i(width, height)

	var map_rect: Rect2 = Rect2(0, 0, width * CELL_SIZE, height * CELL_SIZE)

	# Single dark floor polygon under everything.
	var floor_poly := Polygon2D.new()
	floor_poly.name = "Floor"
	floor_poly.polygon = PackedVector2Array(
		[Vector2.ZERO, Vector2(map_rect.size.x, 0), map_rect.size, Vector2(0, map_rect.size.y)]
	)
	floor_poly.color = COLOR_MAP
	add_child(floor_poly)

	var lit_cells: Dictionary = {}
	var wall_cells: Dictionary = {}
	var terminals: Array[Vector2] = []
	var enemy_spawns: Array[Vector2] = []
	var doors: Array = []
	var door_cells: Dictionary = {}
	var doors_root := Node2D.new()
	doors_root.name = "Doors"
	add_child(doors_root)
	var spawn: Vector2 = map_rect.size / 2.0
	var extraction: Vector2 = spawn

	# Lit cells as merged horizontal runs (visual overlay only, no collision).
	_lit_runs(rows, width, height, lit_cells)

	# Walls as merged horizontal runs with collision.
	_wall_runs(rows, width, height)

	# Special cells.
	for y in range(height):
		for x in range(width):
			match _cell(rows, x, y):
				"1":
					lit_cells[Vector2i(x, y)] = true
				"2":
					wall_cells[Vector2i(x, y)] = true
				"7":
					var door := Door.new()
					door.cell = Vector2i(x, y)
					door.position = _cell_center(x, y)
					doors_root.add_child(door)
					doors.append(door)
					door_cells[Vector2i(x, y)] = true
				"3":
					terminals.append(_cell_center(x, y))
					_draw_marker("Terminal", _cell_center(x, y), 10.0, COLOR_TERMINAL)
				"4":
					spawn = _cell_center(x, y)
					_draw_marker("SpawnMark", _cell_center(x, y), 7.0, COLOR_SPAWN_MARK)
				"5":
					enemy_spawns.append(_cell_center(x, y))
				"6":
					extraction = _cell_center(x, y)
					_draw_marker("Extraction", _cell_center(x, y), 12.0, COLOR_EXTRACTION)

	return {
		"spawn": spawn,
		"wall_cells": wall_cells,
		"zones": zones,
		"doors": doors,
		"door_cells": door_cells,
		"terminals": terminals,
		"extraction": extraction,
		"enemy_spawns": enemy_spawns,
		"lit_cells": lit_cells,
		"bounds": map_rect,
		"grid_size": grid_size,
		"cell_size": CELL_SIZE,
		"origin": Vector2.ZERO,
	}


func _cell(rows: Array, x: int, y: int) -> String:
	if x < 0 or y < 0 or y >= rows.size():
		return ""
	var row: String = rows[y]
	if x >= row.length():
		return ""
	return row[x]


func _cell_center(x: int, y: int) -> Vector2:
	return Vector2(x + 0.5, y + 0.5) * CELL_SIZE


## Adds collisionless visual overlays for lit floor cells (merged per row).
func _lit_runs(rows: Array, width: int, height: int, lit_cells: Dictionary) -> void:
	for y in range(height):
		var run_start: int = -1
		for x in range(width + 1):
			var lit: bool = x < width and _cell(rows, x, y) == "1"
			if lit and run_start < 0:
				run_start = x
			elif not lit and run_start >= 0:
				var poly := Polygon2D.new()
				poly.name = "Lit_%d_%d" % [y, run_start]
				var top: float = y * CELL_SIZE
				poly.polygon = PackedVector2Array([
					Vector2(run_start * CELL_SIZE, top),
					Vector2(x * CELL_SIZE, top),
					Vector2(x * CELL_SIZE, top + CELL_SIZE),
					Vector2(run_start * CELL_SIZE, top + CELL_SIZE),
				])
				poly.color = COLOR_LIT
				add_child(poly)
				run_start = -1


## Adds merged wall runs: one StaticBody2D with a wide rectangle shape each.
func _wall_runs(rows: Array, width: int, height: int) -> void:
	var walls_root := Node2D.new()
	walls_root.name = "Walls"
	add_child(walls_root)
	for y in range(height):
		var run_start: int = -1
		for x in range(width + 1):
			var solid: bool = x < width and _cell(rows, x, y) == "2"
			if solid and run_start < 0:
				run_start = x
			elif not solid and run_start >= 0:
				var body := StaticBody2D.new()
				body.name = "Wall_%d_%d" % [y, run_start]
				var run_width: float = (x - run_start) * CELL_SIZE
				var shape := CollisionShape2D.new()
				var rect := RectangleShape2D.new()
				rect.size = Vector2(run_width, CELL_SIZE)
				shape.shape = rect
				shape.position = Vector2(run_start * CELL_SIZE + run_width / 2.0, y * CELL_SIZE + CELL_SIZE / 2.0)
				body.add_child(shape)
				var visual := Polygon2D.new()
				var top: float = y * CELL_SIZE
				visual.polygon = PackedVector2Array([
					Vector2(run_start * CELL_SIZE, top),
					Vector2(x * CELL_SIZE, top),
					Vector2(x * CELL_SIZE, top + CELL_SIZE),
					Vector2(run_start * CELL_SIZE, top + CELL_SIZE),
				])
				visual.color = COLOR_WALL
				body.add_child(visual)
				walls_root.add_child(body)
				run_start = -1


func _draw_marker(label: String, center: Vector2, radius: float, color: Color) -> void:
	var node := Polygon2D.new()
	node.name = label
	node.polygon = _circle_polygon(radius, 12)
	node.color = color
	node.position = center
	add_child(node)


func _circle_polygon(radius: float, points: int) -> PackedVector2Array:
	var array := PackedVector2Array()
	for i in range(points):
		var angle: float = TAU * i / points
		array.append(Vector2(cos(angle), sin(angle)) * radius)
	return array
