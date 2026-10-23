extends Node2D
## Shadow Protocol - main scene controller (Phases 1-4).
##
## Owns the level lifecycle: loads a level DESCRIPTOR from LevelCatalog
## (authored layout or seeded procedural generation), builds the level,
## repositions the player, configures StealthSystem (including wall
## cells and doors), spawns lights from layout metadata, spawns enemies
## from grid markers with wall/door-aware patrol routes, wires the touch
## controls, and runs the per-frame visibility update and debug HUD.
##
## Level lifecycle (Phase 4): load_level() clears the previous level
## (enemies freed, lights freed, doors unregistered, subscriptions
## dropped, stale collision removed) before building the new one, so
## sequential level switches never duplicate enemies, leak light
## registrations, or leave dangling state.

@onready var player: CharacterBody2D = $Player
@onready var level_root: Node2D = $LevelRoot
@onready var touch_layer: Control = $UI/TouchLayer
@onready var hud: Label = $UI/HUD
@onready var status: Label = $UI/Status
@onready var meter: Control = $UI/VisibilityMeter

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")

const HUD_TEMPLATE := "SHADOW PROTOCOL - Phase 4 build - level: %s
Speed: %s px/s
Crouch: %s   Sprint: %s
Noise radius: %s px
Grid: %s   Lights: %s   Enemies: %s
Zone: %s
%s"

var level_data: Dictionary = {}
var current_descriptor: Dictionary = {}
var level_label: String = ""
var enemies: Array[Node] = []
var _level_lights: Array[Node] = []
var _status_timer: float = 0.0


func _ready() -> void:
	# One-time wiring that does not depend on the level.
	player.set_touch_controls(touch_layer)
	touch_layer.crouch_toggled.connect(player.set_touch_crouch)
	touch_layer.sprint_toggled.connect(player.set_touch_sprint)
	touch_layer.interact_pressed.connect(_on_interact)
	player.interact_requested.connect(_on_interact)
	player.noise_emitted.connect(_on_player_noise)

	await load_level(LevelCatalog.default_descriptor())


## Loads (or switches to) the level described by [param descriptor].
## Safe to call repeatedly: the previous level is torn down first.
func load_level(descriptor: Dictionary) -> void:
	await _clear_level()

	current_descriptor = descriptor
	level_label = str(descriptor.get("label", "?"))
	var rows: Array = descriptor["rows"]
	var zones: Array = descriptor.get("zones", [])
	level_data = level_root.generate(rows, zones)
	player.position = level_data["spawn"]
	StealthSystem.configure(
		level_data["lit_cells"], level_data["cell_size"], level_data["origin"],
		level_data["wall_cells"]
	)

	# Camera confined to the generated map.
	var camera: Camera2D = player.camera
	var bounds: Rect2 = level_data["bounds"]
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(bounds.size.x)
	camera.limit_bottom = int(bounds.size.y)
	camera.make_current()

	# Doors: registered so is_cell_blocked() tracks their live state.
	for door: Node in level_data["doors"]:
		StealthSystem.register_door(door)
		door.state_changed.connect(_on_door_state_changed)

	_spawn_lights(descriptor)
	_spawn_enemies()

	print("SHADOW PROTOCOL: level '%s' generated (grid %s), player at %s, lights: %d, enemies: %d" % [
		level_label, level_data["grid_size"], level_data["spawn"],
		StealthSystem.light_count(), enemies.size()
	])


## Tears down the current level: enemies, lights and door registrations
## are removed before the next build; the player instance is reused.
func _clear_level() -> void:
	for enemy: Node in enemies:
		enemy.queue_free()
	enemies.clear()
	for light: Node in _level_lights:
		light.queue_free()
	_level_lights.clear()
	StealthSystem.clear_doors()
	# Let queue_free() settle so stale collision bodies are gone before
	# the next generation (sequential level switching safety).
	await get_tree().process_frame
	await get_tree().process_frame


func _spawn_lights(descriptor: Dictionary) -> void:
	# Static lamps come from layout metadata so generated maps get valid
	# placements (no hard-coded coordinates from the legacy map).
	for lamp: Dictionary in descriptor.get("lights", []):
		var light := LightSource.new()
		light.position = lamp["pos"]
		light.light_radius = lamp["radius"]
		light.light_intensity = lamp["intensity"]
		add_child(light)
		_level_lights.append(light)
	for ml: Dictionary in descriptor.get("moving_lights", []):
		var moving := MovingLight.new()
		moving.light_radius = ml["radius"]
		moving.light_intensity = ml["intensity"]
		moving.point_a = ml["a"]
		moving.point_b = ml["b"]
		moving.speed = ml["speed"]
		add_child(moving)
		_level_lights.append(moving)


## Phase 3 (P3-T5): spawn one reusable enemy per grid marker '5', with a
## deterministic, wall/door-aware patrol route, player reference and noise
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
## straight line (no wall or closed-door cells) - enemies never walk
## into walls or closed doors toward unreachable targets. Navigation
## queries go through StealthSystem so door state changes are honored.
func _build_patrol_route(spawn_world: Vector2) -> Array[Vector2]:
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
				if seen.has(nc) or StealthSystem.is_cell_blocked(nc):
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
			if not _grid_los(current, candidate, cell_size, origin):
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


## Straight-line navigation check between two cell centers (sampled at
## quarter-cell steps), using StealthSystem so closed doors block.
func _grid_los(a: Vector2i, b: Vector2i, cell_size: float, origin: Vector2) -> bool:
	var from_world: Vector2 = origin + Vector2(a) * cell_size + Vector2(cell_size, cell_size) * 0.5
	var to_world: Vector2 = origin + Vector2(b) * cell_size + Vector2(cell_size, cell_size) * 0.5
	var steps: int = maxi(2, int(from_world.distance_to(to_world) / (cell_size * 0.25)))
	for i in range(steps + 1):
		var sample: Vector2 = from_world.lerp(to_world, float(i) / float(steps))
		var cell: Vector2i = Vector2i(int((sample.x - origin.x) / cell_size), int((sample.y - origin.y) / cell_size))
		if StealthSystem.is_cell_blocked(cell):
			return false
	return true


func _exit_tree() -> void:
	# Whole-scene teardown (e.g. tests freeing the main scene): no stale
	# door registrations survive the scene itself.
	StealthSystem.clear_doors()


func _process(delta: float) -> void:
	if level_data.is_empty():
		return  # async level load has not completed yet
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


func _update_hud() -> void:
	var zone: StringName = LevelCatalog.zone_at(
		level_data.get("zones", []), player.global_position,
		level_data["cell_size"], level_data["origin"]
	)
	hud.text = HUD_TEMPLATE % [
		level_label,
		"%.0f" % player.velocity.length(),
		"yes" if player.crouching else "no",
		"yes" if player.sprinting else "no",
		"%.0f" % StealthSystem.noise_radius(player.crouching, player.speed_ratio, player.sprinting),
		"%s" % [level_data["grid_size"]],
		"%d" % StealthSystem.light_count(),
		"%d" % enemies.size(),
		zone,
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


## Door state changes: patrol-route navigation data stays fresh - enemy
## routes are rebuilt so open doors become usable and closed ones avoided.
func _on_door_state_changed(is_open: bool) -> void:
	for enemy: Node in enemies:
		enemy.set_patrol_route(_build_patrol_route(enemy.global_position))


## Future-HUD hook: state transitions surface as status feedback.
func _on_enemy_state(from_state: StringName, to_state: StringName) -> void:
	if to_state == &"alert":
		_show_status("DETECTED - an enemy has seen you!")


func _show_status(message: String) -> void:
	status.text = message
	_status_timer = 2.5
