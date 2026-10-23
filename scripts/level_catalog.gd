class_name LevelCatalog
## Shadow Protocol - level catalog and procedural generator (Phase 4).
##
## CENTRAL TILE ENCODING (the single authoritative definition; the level
## generator and every layout must use exactly these characters):
##   '0' shadow floor    '1' illuminated floor   '2' solid wall
##   '3' mission terminal '4' player spawn        '5' enemy spawn
##   '6' extraction point '7' door (closed by default)
##
## A level DESCRIPTOR is a Dictionary:
##   label         String          diagnostic name
##   rows          Array[String]   the authoritative grid
##   zones         Array           [{id: StringName, rect: Rect2i}] in cells
##   lights        Array           [{pos, radius, intensity}] static lamps
##   moving_lights Array           [{a, b, radius, intensity, speed}]
##   seed/attempts/fallback/reason  set by generate_layout()
##
## Authored layouts: LEGACY (Phase 1-3 regression fixture, unchanged
## geometry), LAYOUT_B (two north rooms, door passages, big south hall
## with restricted lit depots), LAYOUT_C (ring corridors around a
## restricted central vault with three doors).
##
## Restricted zones are foundational spatial metadata (id + deterministic
## cell rect); they do not change existing gameplay in Phase 4.
##
## Procedural generation is a bounded rooms-and-corridors algorithm
## driven by its own RandomNumberGenerator instance: the same seed
## reproduces the same logical level, independent of global randomness.

const MAX_ATTEMPTS: int = 25
const GRID_W: int = 28
const GRID_H: int = 16
const CELL: float = 48.0

# ---------------------------------------------------------------- legacy --

const LEGACY_ROWS: Array[String] = [
	"2222222222222222222222222222",
	"2400000000200001000200000302",
	"2000000000000001000200000002",
	"2000000000200001000200000002",
	"2002222000200000000202220002",
	"2002002000200111100202020002",
	"2002002000200150100202020002",
	"2002002000200100100002020002",
	"2002002000200111100202020002",
	"2002002000200000000202020002",
	"2002222000200001000202220002",
	"2000000000200001000200000002",
	"2000500000000001000000060002",
	"2000000000200001000200000002",
	"2000000000200001000200000002",
	"2222222222222222222222222222",
]

const LEGACY := {
	"label": "legacy",
	"rows": LEGACY_ROWS,
	"zones": [
		{"id": &"zone_hall", "rect": Rect2i(13, 5, 4, 4)},
	],
	"lights": [
		{"pos": Vector2(720.0, 168.0), "radius": 150.0, "intensity": 0.7},
		{"pos": Vector2(624.0, 360.0), "radius": 150.0, "intensity": 0.7},
		{"pos": Vector2(720.0, 648.0), "radius": 150.0, "intensity": 0.7},
		{"pos": Vector2(144.0, 120.0), "radius": 110.0, "intensity": 0.45},
	],
	"moving_lights": [
		{"a": Vector2(528.0, 216.0), "b": Vector2(864.0, 216.0),
			"radius": 130.0, "intensity": 0.6, "speed": 70.0},
	],
}

const LAYOUT_B_ROWS: Array[String] = [
	"2222222222222222222222222222",
	"2000000000222111111120000002",
	"2040000000222111111100000002",
	"2000000000222111111120005002",
	"2000000000070111111120000002",
	"2000000030222111311120000002",
	"2000000000222111111120000002",
	"2222227222222222722222227222",
	"2000000000000000000000000002",
	"2000000000000000000000000002",
	"2011111100000111111000111112",
	"2015111100000111111000111112",
	"2011111100000111111000111112",
	"2000000000000000000000000062",
	"2000000000000000000000000002",
	"2222222222222222222222222222",
]

const LAYOUT_B := {
	"label": "layout_b",
	"rows": LAYOUT_B_ROWS,
	"zones": [
		{"id": &"zone_north_lab", "rect": Rect2i(13, 1, 7, 6)},
		{"id": &"zone_west_depot", "rect": Rect2i(2, 10, 6, 3)},
		{"id": &"zone_central_depot", "rect": Rect2i(13, 10, 6, 3)},
		{"id": &"zone_east_depot", "rect": Rect2i(22, 10, 5, 3)},
	],
	"lights": [
		{"pos": Vector2(768.0, 168.0), "radius": 160.0, "intensity": 0.7},
		{"pos": Vector2(744.0, 528.0), "radius": 140.0, "intensity": 0.65},
		{"pos": Vector2(1080.0, 624.0), "radius": 150.0, "intensity": 0.7},
	],
	"moving_lights": [],
}

const LAYOUT_C_ROWS: Array[String] = [
	"2222222222222222222222222222",
	"2000000000000000000000000002",
	"2040000000000000000000000002",
	"2000000000000000000000000002",
	"2000000000000000000000000002",
	"2000000000000000000000000002",
	"2000000211111111111120000002",
	"2000000711111311111170000002",
	"2000000211111111111120000502",
	"2000000211111111111120000002",
	"2000000222222722222220000002",
	"2000000000000000000000000002",
	"2005000000000000000000000002",
	"2000000005000000000000000062",
	"2000000000000000000000000002",
	"2222222222222222222222222222",
]

const LAYOUT_C := {
	"label": "layout_c",
	"rows": LAYOUT_C_ROWS,
	"zones": [
		{"id": &"zone_vault", "rect": Rect2i(8, 6, 12, 4)},
	],
	"lights": [
		{"pos": Vector2(720.0, 384.0), "radius": 170.0, "intensity": 0.75},
	],
	"moving_lights": [
		{"a": Vector2(72.0, 264.0), "b": Vector2(1224.0, 264.0),
			"radius": 120.0, "intensity": 0.5, "speed": 90.0},
	],
}

const AUTHORED_LAYOUTS: Array = [LEGACY, LAYOUT_B, LAYOUT_C]


static func default_descriptor() -> Dictionary:
	return LEGACY


# ------------------------------------------------------------- validation --

## Validates a grid against the central encoding and reachability rules.
## Doors are treated as passable: they are openable by design, so a door
## on the only route is CONDITIONAL reachability, not a dead map.
## Returns {valid: bool, reason: String}.
static func validate_rows(rows: Array) -> Dictionary:
	if rows.size() < 12 or (rows[0] as String).length() < 12:
		return {"valid": false, "reason": "grid too small (min 12x12)"}
	var width: int = (rows[0] as String).length()
	var counts := {}
	for y in range(rows.size()):
		var row := rows[y] as String
		if row.length() != width:
			return {"valid": false, "reason": "ragged row %d" % y}
		for x in range(width):
			var c := row[x]
			if not "01234567".contains(c):
				return {"valid": false, "reason": "invalid tile '%s' at %d,%d" % [c, x, y]}
			counts[c] = counts.get(c, 0) + 1
	if counts.get("4", 0) != 1:
		return {"valid": false, "reason": "expected exactly one player spawn"}
	if counts.get("6", 0) != 1:
		return {"valid": false, "reason": "expected exactly one extraction point"}
	if counts.get("3", 0) < 1:
		return {"valid": false, "reason": "missing mission terminal"}
	if counts.get("5", 0) < 1:
		return {"valid": false, "reason": "missing enemy spawn"}
	# Door chokepoint rule: a door must sit in a single-tile passage.
	for y in range(rows.size()):
		for x in range(width):
			if (rows[y] as String)[x] != "7":
				continue
			if not _is_chokepoint(rows, x, y):
				return {"valid": false,
					"reason": "door at %d,%d is not a single-tile passage" % [x, y]}
	# BFS reachability (doors passable) from the player spawn.
	var spawn := _find_first(rows, "4")
	var reach := _reachable(rows, spawn)
	for marker in ["3", "5", "6"]:
		var pos := _find_first(rows, marker)
		while pos.x >= 0:
			if not reach.has(pos):
				return {"valid": false,
					"reason": "marker '%s' at %d,%d is unreachable" % [marker, pos.x, pos.y]}
			pos = _find_next(rows, marker, pos)
	return {"valid": true, "reason": ""}


## Zone validation: rects inside the grid, non-empty, and no overlapping
## rectangles carrying different ids (predictable rejection).
static func validate_zones(zones: Array, rows: Array) -> Dictionary:
	var width: int = (rows[0] as String).length()
	var height: int = rows.size()
	for i in range(zones.size()):
		var rect: Rect2i = zones[i]["rect"]
		if rect.size.x <= 0 or rect.size.y <= 0:
			return {"valid": false, "reason": "zone %d is empty" % i}
		if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > width or rect.end.y > height:
			return {"valid": false, "reason": "zone %d out of grid bounds" % i}
		for j in range(i + 1, zones.size()):
			if zones[i]["id"] != zones[j]["id"] and rect.intersects(zones[j]["rect"]):
				return {"valid": false,
					"reason": "zones '%s' and '%s' overlap" % [zones[i]["id"], zones[j]["id"]]}
	return {"valid": true, "reason": ""}


static func _is_chokepoint(rows: Array, x: int, y: int) -> bool:
	var east := _tile_at(rows, x + 1, y)
	var west := _tile_at(rows, x - 1, y)
	var north := _tile_at(rows, x, y - 1)
	var south := _tile_at(rows, x, y + 1)
	var walls_east_west: bool = east == "2" and west == "2"
	var walls_north_south: bool = north == "2" and south == "2"
	var passable_north_south: bool = _is_passable(north) and _is_passable(south)
	var passable_east_west: bool = _is_passable(east) and _is_passable(west)
	return (walls_east_west and passable_north_south) or (walls_north_south and passable_east_west)


static func _is_passable(c: String) -> bool:
	return c != "" and c != "2"


static func _tile_at(rows: Array, x: int, y: int) -> String:
	if y < 0 or y >= rows.size():
		return ""
	var row := rows[y] as String
	if x < 0 or x >= row.length():
		return ""
	return row[x]


static func _find_first(rows: Array, tile: String) -> Vector2i:
	for y in range(rows.size()):
		var x: int = (rows[y] as String).find(tile)
		if x >= 0:
			return Vector2i(x, y)
	return Vector2i(-1, -1)


static func _find_next(rows: Array, tile: String, after: Vector2i) -> Vector2i:
	for y in range(after.y, rows.size()):
		var row := rows[y] as String
		var from_x: int = after.x + 1 if y == after.y else 0
		var x: int = row.find(tile, from_x)
		if x >= 0:
			return Vector2i(x, y)
	return Vector2i(-1, -1)


static func _reachable(rows: Array, start: Vector2i) -> Dictionary:
	var seen: Dictionary = {start: true}
	var frontier: Array[Vector2i] = [start]
	while frontier.size() > 0:
		var next: Array[Vector2i] = []
		for cell: Vector2i in frontier:
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nc: Vector2i = cell + d
				if seen.has(nc) or not _is_passable(_tile_at(rows, nc.x, nc.y)):
					continue
				seen[nc] = true
				next.append(nc)
		frontier = next
	return seen


# ------------------------------------------------------------------ zones --

## Stable zone membership query by world position: the id of the zone
## containing the position, or an empty StringName outside every zone.
## Deterministic: membership is the cell rectangle intersection.
static func zone_at(zones: Array, world_pos: Vector2, cell_size: float, origin: Vector2) -> StringName:
	var cell := Vector2i(int((world_pos.x - origin.x) / cell_size), int((world_pos.y - origin.y) / cell_size))
	for zone in zones:
		if (zone["rect"] as Rect2i).has_point(cell):
			return zone["id"]
	return &""


# ------------------------------------------------------- procedural (P4-T2) --

## Seeded, bounded, reproducible layout generation. Same seed -> same
## logical level (own RandomNumberGenerator; no global RNG use). Invalid
## candidates are rejected with a recorded reason; after MAX_ATTEMPTS the
## explicitly documented, validated LEGACY fallback is returned with
## fallback=true and the failure reason - never an invalid map.
static func generate_layout(seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var attempts: int = 0
	var last_reason := ""
	while attempts < MAX_ATTEMPTS:
		attempts += 1
		var candidate := _build_candidate(rng)
		var v := validate_rows(candidate["rows"])
		if not v["valid"]:
			last_reason = v["reason"]
			continue
		var vz := validate_zones(candidate["zones"], candidate["rows"])
		if not vz["valid"]:
			last_reason = vz["reason"]
			continue
		candidate["label"] = "seed_%d" % seed
		candidate["seed"] = seed
		candidate["attempts"] = attempts
		candidate["fallback"] = false
		candidate["reason"] = ""
		return candidate
	var fb := LEGACY.duplicate(true)
	fb["seed"] = seed
	fb["attempts"] = attempts
	fb["fallback"] = true
	fb["reason"] = "generation attempts exceeded (%s)" % last_reason
	return fb


## Rooms-and-corridors candidate: 4-6 non-overlapping rooms, L corridors
## in a stable order (room 0 to 1, 1 to 2, ...), deterministic seeded
## marker placement, chokepoint doors, restricted zones on lit rooms.
static func _build_candidate(rng: RandomNumberGenerator) -> Dictionary:
	var rows: Array[String] = []
	for y in range(GRID_H):
		rows.append("2".repeat(GRID_W))

	var rooms: Array[Rect2i] = []
	var room_target: int = rng.randi_range(4, 6)
	for i in range(room_target):
		var placed: bool = false
		for try_n in range(40):
			var w: int = rng.randi_range(4, 8)
			var h: int = rng.randi_range(4, 7)
			var x: int = rng.randi_range(1, GRID_W - w - 2)
			var y: int = rng.randi_range(1, GRID_H - h - 2)
			var rect := Rect2i(x, y, w, h)
			var overlapping := false
			for other: Rect2i in rooms:
				if rect.grow(1).intersects(other):
					overlapping = true
					break
			if not overlapping:
				rooms.append(rect)
				placed = true
				break
		if not placed:
			break
	if rooms.size() < 3:
		return {"rows": rows, "zones": [], "lights": [], "moving_lights": []}

	# Carve rooms; ~40% become illuminated (and thus restricted zones).
	var zones: Array = []
	var lights: Array = []
	for room: Rect2i in rooms:
		var lit: bool = rng.randf() < 0.4
		var tile := "1" if lit else "0"
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x):
				rows[y] = rows[y].substr(0, x) + tile + rows[y].substr(x + 1)
		if lit:
			zones.append({"id": StringName("zone_%d" % (zones.size() + 1)), "rect": room})
			lights.append({
				"pos": Vector2(room.position.x + room.size.x / 2.0, room.position.y + room.size.y / 2.0) * CELL,
				"radius": float(rng.randi_range(120, 170)),
				"intensity": 0.5 + rng.randf_range(0.0, 0.3),
			})

	# Stable-order L corridors between consecutive rooms.
	for i in range(rooms.size() - 1):
		var a := Vector2i(rooms[i].position.x + rooms[i].size.x / 2, rooms[i].position.y + rooms[i].size.y / 2)
		var b := Vector2i(rooms[i + 1].position.x + rooms[i + 1].size.x / 2, rooms[i + 1].position.y + rooms[i + 1].size.y / 2)
		var vertical_first: bool = rng.randf() < 0.5
		if vertical_first:
			_carve_column(rows, Vector2i(a.x, a.y), b.y)
			_carve_row(rows, Vector2i(a.x, b.y), b.x)
		else:
			_carve_row(rows, Vector2i(a.x, a.y), b.x)
			_carve_column(rows, Vector2i(b.x, a.y), b.y)

	# Markers: spawn in room 0, extraction in the farthest room, terminals
	# and enemies in remaining rooms (deterministic order).
	var spawn_room: Rect2i = rooms[0]
	var spawn_cell := Vector2i(spawn_room.position.x + spawn_room.size.x / 2, spawn_room.position.y + spawn_room.size.y / 2)
	_set_tile(rows, spawn_cell, "4")
	var far_room: Rect2i = rooms[rooms.size() - 1]
	var far_dist: int = -1
	for room: Rect2i in rooms:
		var d: int = absi(room.position.x - spawn_room.position.x) + absi(room.position.y - spawn_room.position.y)
		if d > far_dist:
			far_dist = d
			far_room = room
	var extraction := Vector2i(far_room.position.x + far_room.size.x / 2, far_room.position.y + far_room.size.y / 2)
	_set_tile(rows, extraction, "6")
	var terminals_placed: int = 0
	var enemies_placed: int = 0
	for room: Rect2i in rooms:
		if room == spawn_room or room == far_room:
			continue
		var inner := _inner_cells(room)
		if terminals_placed < 2 and inner.size() > 0:
			var t := inner[rng.randi_range(0, inner.size() - 1)]
			_set_tile(rows, t, "3")
			terminals_placed += 1
		if enemies_placed < 3 and inner.size() > 0:
			var enemy_cell := inner[rng.randi_range(0, inner.size() - 1)]
			if _tile_at(rows, enemy_cell.x, enemy_cell.y) not in ["3", "4", "6"]:
				_set_tile(rows, enemy_cell, "5")
				enemies_placed += 1

	# Doors: up to 2 chokepoints on plain corridor cells ('0').
	var chokes: Array[Vector2i] = []
	for y in range(1, GRID_H - 1):
		for x in range(1, GRID_W - 1):
			if rows[y][x] == "0" and _is_chokepoint(rows, x, y):
				chokes.append(Vector2i(x, y))
	for i in range(mini(2, chokes.size())):
		var pick: int = rng.randi_range(0, chokes.size() - 1)
		_set_tile(rows, chokes[pick], "7")
		chokes.remove_at(pick)

	return {"rows": rows, "zones": zones, "lights": lights, "moving_lights": []}


static func _carve_row(rows: Array[String], from_cell: Vector2i, to_x: int) -> void:
	var x0: int = mini(from_cell.x, to_x)
	var x1: int = maxi(from_cell.x, to_x)
	for x in range(x0, x1 + 1):
		if rows[from_cell.y][x] == "2":
			rows[from_cell.y] = rows[from_cell.y].substr(0, x) + "0" + rows[from_cell.y].substr(x + 1)


static func _carve_column(rows: Array[String], from_cell: Vector2i, to_y: int) -> void:
	var y0: int = mini(from_cell.y, to_y)
	var y1: int = maxi(from_cell.y, to_y)
	for y in range(y0, y1 + 1):
		if rows[y][from_cell.x] == "2":
			rows[y] = rows[y].substr(0, from_cell.x) + "0" + rows[y].substr(from_cell.x + 1)


static func _inner_cells(room: Rect2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			cells.append(Vector2i(x, y))
	return cells


static func _set_tile(rows: Array[String], cell: Vector2i, tile: String) -> void:
	rows[cell.y] = rows[cell.y].substr(0, cell.x) + tile + rows[cell.y].substr(cell.x + 1)
