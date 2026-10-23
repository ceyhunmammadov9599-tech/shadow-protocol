extends Node2D
## Shadow Protocol - main scene controller (Phases 1-2).
##
## Owns the level lifecycle: generates the test level from the grid, places
## the player, wires the touch controls, dynamic lights, the StealthSystem
## autoload, the visibility meter and the noise event pipeline, runs the
## per-frame visibility update and the debug HUD.

## Test level (16 x 28). Values: 0 shadow floor, 1 lit floor, 2 wall,
## 3 terminal, 4 player spawn, 5 enemy spawn, 6 extraction.
## Verified: every marker reachable from spawn (flood fill); two enemy
## spawn points (5) for independent multi-enemy behavior.
## Phase 3 fix: walls now use the documented character '2' - previously
## '#' cells produced no wall collision at all (see Phase 3 report).
const TEST_GRID: Array[String] = [
	"2222222222222222222222222222",
	"24........2....1...2.....3.2",
	"2..............1...2.......2",
	"2.........2....1...2.......2",
	"2..2222...2........2.222...2",
	"2..2..2...2..1111..2.2.2...2",
	"2..2..2...2..15.1..2.2.2...2",
	"2..2..2...2..1..1....2.2...2",
	"2..2..2...2..1111..2.2.2...2",
	"2..2..2...2........2.2.2...2",
	"2..2222...2....1...2.222...2",
	"2.........2....1...2.......2",
	"2...5..........1.......6...2",
	"2.........2....1...2.......2",
	"2.........2....1...2.......2",
	"2222222222222222222222222222"
]

## Static lamp positions (world pixels). Authored inside rooms so their
## radius does not cross walls (documented approximation in light_source.gd).
const STATIC_LIGHTS: Array[Vector2] = [
	Vector2(720.0, 168.0),   # north corridor lamp
	Vector2(624.0, 360.0),   # central hall lamp
	Vector2(720.0, 648.0),   # south corridor lamp
	Vector2(144.0, 120.0),    # spawn room corner lamp (dim)
]
const STATIC_LIGHT_RADIUS: float = 150.0
const STATIC_LIGHT_INTENSITY: float = 0.7
const SPAWN_LIGHT_RADIUS: float = 110.0
const SPAWN_LIGHT_INTENSITY: float = 0.45

## Moving lamp patrolling the central corridor (demonstrates dynamic lights).
const MOVING_LIGHT_A := Vector2(528.0, 216.0)
const MOVING_LIGHT_B := Vector2(864.0, 216.0)
const MOVING_LIGHT_RADIUS: float = 130.0
const MOVING_LIGHT_INTENSITY: float = 0.6
const MOVING_LIGHT_SPEED: float = 70.0

const HUD_TEMPLATE := "SHADOW PROTOCOL - Phase 3 build
Speed: %s px/s
Crouch: %s   Sprint: %s
Noise radius: %s px
Grid: %s   Lights: %s   Enemies: %s
%s"

@onready var player: CharacterBody2D = $Player
@onready var level_root: Node2D = $LevelRoot
@onready var touch_layer: Control = $UI/TouchLayer
@onready var hud: Label = $UI/HUD
@onready var status: Label = $UI/Status
@onready var meter: Control = $UI/VisibilityMeter

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")

var level_data: Dictionary = {}
var _status_timer: float = 0.0
var _noise_events_seen: int = 0
var enemies: Array[Node] = []


func _ready() -> void:
	level_data = level_root.generate(TEST_GRID)
	player.position = level_data["spawn"]
	StealthSystem.configure(
		level_data["lit_cells"], level_data["cell_size"], level_data["origin"]
	)

	# Camera confined to the generated map.
	var camera: Camera2D = player.camera
	var bounds: Rect2 = level_data["bounds"]
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(bounds.size.x)
	camera.limit_bottom = int(bounds.size.y)
	camera.make_current()

	# Touch controls integration (explicit single wiring point).
	player.set_touch_controls(touch_layer)
	touch_layer.crouch_toggled.connect(player.set_touch_crouch)
	touch_layer.sprint_toggled.connect(player.set_touch_sprint)
	touch_layer.interact_pressed.connect(_on_interact)
	player.interact_requested.connect(_on_interact)

	# Noise pipeline: player noise -> central StealthSystem publication.
	player.noise_emitted.connect(_on_player_noise)

	_spawn_lights()
	_spawn_enemies()

	print("SHADOW PROTOCOL: Phase 3 level generated (grid %s), player at %s, lights: %d, enemies: %d" % [
		level_data["grid_size"], level_data["spawn"], StealthSystem.light_count(), enemies.size()
	])


func _process(delta: float) -> void:
	# Visibility model update (grid lookup + few-light distance math).
	var visibility: float = StealthSystem.compute_visibility(
		player.global_position, player.crouching, player.speed_ratio
	)
	player.set_visibility(visibility)
	meter.set_value(visibility)
	_update_hud()
	if _status_timer > 0.0:
		_status_timer -= delta
		if _status_timer <= 0.0:
			status.text = ""


func _spawn_lights() -> void:
	for i in range(STATIC_LIGHTS.size()):
		var light := LightSource.new()
		light.position = STATIC_LIGHTS[i]
		light.light_radius = SPAWN_LIGHT_RADIUS if i == 3 else STATIC_LIGHT_RADIUS
		light.light_intensity = SPAWN_LIGHT_INTENSITY if i == 3 else STATIC_LIGHT_INTENSITY
		add_child(light)

	var moving := MovingLight.new()
	moving.light_radius = MOVING_LIGHT_RADIUS
	moving.light_intensity = MOVING_LIGHT_INTENSITY
	moving.point_a = MOVING_LIGHT_A
	moving.point_b = MOVING_LIGHT_B
	moving.speed = MOVING_LIGHT_SPEED
	add_child(moving)


## Phase 3 (P3-T5): spawn one reusable enemy per grid marker '5', with a
## deterministic, wall-aware patrol route, player reference and noise
## subscriptions (wired inside the enemy itself).
func _spawn_enemies() -> void:
	var spawns: Array = level_data["enemy_spawns"]
	for i in range(spawns.size()):
		var enemy: CharacterBody2D = ENEMY_SCENE.instantiate()
		enemy.position = spawns[i]
		enemy.set_enemy_id(StringName("enemy_%d" % (i + 1)))
		enemy.set_player(player)
		enemy.set_patrol_route(_build_patrol_route(spawns[i]))
		enemy.state_changed.connect(_on_enemy_state)
		add_child(enemy)
		enemies.append(enemy)


## Deterministic patrol route around a spawn: open cells within BFS
## distance 4, chained greedily so every consecutive pair has a clear
## straight line (no wall cells) - enemies never walk into walls toward
## unreachable targets.
func _build_patrol_route(spawn_world: Vector2) -> Array[Vector2]:
	var walls: Dictionary = level_data["wall_cells"]
	var cell_size: float = level_data["cell_size"]
	var origin: Vector2 = level_data["origin"]
	var start: Vector2i = Vector2i(int((spawn_world.x - origin.x) / cell_size), int((spawn_world.y - origin.y) / cell_size))
	var open_cells: Array[Vector2i] = []
	var seen: Dictionary = {start: true}
	var frontier: Array[Vector2i] = [start]
	for step in range(4):
		var next: Array[Vector2i] = []
		for cell: Vector2i in frontier:
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nc: Vector2i = cell + d
				if seen.has(nc) or walls.has(nc):
					continue
				seen[nc] = true
				open_cells.append(nc)
				next.append(nc)
		frontier = next
	var route: Array[Vector2] = [spawn_world]
	var current: Vector2i = start
	var used: Dictionary = {start: true}
	while route.size() < 4 and open_cells.size() > 0:
		var best_cell: Vector2i = Vector2i(-9999, -9999)
		var best_dist: float = -1.0
		for candidate: Vector2i in open_cells:
			if used.has(candidate):
				continue
			if not _grid_los(current, candidate, walls, cell_size, origin):
				continue
			var dist: float = (Vector2(candidate - current) * cell_size).length()
			if dist > best_dist:
				best_dist = dist
				best_cell = candidate
		if best_cell == Vector2i(-9999, -9999):
			break
		used[best_cell] = true
		route.append(origin + Vector2(best_cell) * cell_size + Vector2(cell_size, cell_size) * 0.5)
		current = best_cell
	return route


## Straight-line wall check between two cell centers (sampled at quarter-cell
## steps). Deterministic; used only for patrol-route construction.
func _grid_los(a: Vector2i, b: Vector2i, walls: Dictionary, cell_size: float, origin: Vector2) -> bool:
	var from_world: Vector2 = origin + Vector2(a) * cell_size + Vector2(cell_size, cell_size) * 0.5
	var to_world: Vector2 = origin + Vector2(b) * cell_size + Vector2(cell_size, cell_size) * 0.5
	var steps: int = maxi(2, int(from_world.distance_to(to_world) / (cell_size * 0.25)))
	for i in range(steps + 1):
		var sample: Vector2 = from_world.lerp(to_world, float(i) / float(steps))
		var cell: Vector2i = Vector2i(int((sample.x - origin.x) / cell_size), int((sample.y - origin.y) / cell_size))
		if walls.has(cell):
			return false
	return true


## Future-HUD hook: state transitions surface as status feedback.
func _on_enemy_state(from_state: StringName, to_state: StringName) -> void:
	if to_state == &"alert":
		_show_status("DETECTED - an enemy has seen you!")


func _update_hud() -> void:
	hud.text = HUD_TEMPLATE % [
		"%.0f" % player.velocity.length(),
		"yes" if player.crouching else "no",
		"yes" if player.sprinting else "no",
		"%.0f" % StealthSystem.noise_radius(player.crouching, player.speed_ratio, player.sprinting),
		"%s" % [level_data["grid_size"]],
		"%d" % StealthSystem.light_count(),
		"%d" % enemies.size(),
		"WASD move - C crouch - Shift sprint - E interact",
	]


func _on_interact() -> void:
	# Context-sensitive interaction: terminals first, then extraction.
	for terminal: Vector2 in level_data["terminals"]:
		if player.global_position.distance_to(terminal) < 60.0:
			_show_status("Terminal detected. Mission systems arrive in Phase 5.")
			return
	var extraction: Vector2 = level_data["extraction"]
	if player.global_position.distance_to(extraction) < 60.0:
		_show_status("Extraction point. Mission completion arrives in Phase 5.")
		return
	_show_status("Nothing to interact with here.")


## Player noise -> StealthSystem publication (with movement-state metadata).
func _on_player_noise(pos: Vector2, radius: float) -> void:
	StealthSystem.publish_noise(pos, radius, &"player", player.current_movement_state())


func _show_status(message: String) -> void:
	status.text = message
	_status_timer = 2.5
