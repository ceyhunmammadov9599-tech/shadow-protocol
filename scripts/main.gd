class_name Main
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
@onready var detection_meter: Control = $UI/DetectionMeter

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")

# Phase 7 benchmarking: HUD rebuild counter, enabled only by the
# benchmark harness. Zero behavior change.
static var bench_enabled: bool = false
static var bench_hud_rebuilds: int = 0


static func bench_reset() -> void:
	bench_hud_rebuilds = 0


const HUD_TEMPLATE := "SHADOW PROTOCOL - %s
Mission %s   Obj %d/%d   Extract %s
Zone %s
%s
C crouch  Shift sprint  E use  R restart"

var level_data: Dictionary = {}
var current_descriptor: Dictionary = {}
var level_label: String = ""
var enemies: Array[Node] = []
var _level_lights: Array[Node] = []
var _status_timer: float = 0.0
# Phase 5: mission system.
var mission_manager: MissionManager
var feedback_manager: FeedbackManager
const INTERACTION_RADIUS: float = 80.0
var interaction_radius: float = INTERACTION_RADIUS  # configurable per level/tests
var _interact_target: Node = null  # nearest eligible terminal/door (throttled)
var _interact_search_timer: float = 0.0
var _hud_action_hint := ""


func _ready() -> void:
	# One-time wiring that does not depend on the level.
	player.set_touch_controls(touch_layer)
	touch_layer.crouch_toggled.connect(player.set_touch_crouch)
	touch_layer.sprint_toggled.connect(player.set_touch_sprint)
	touch_layer.interact_pressed.connect(_on_interact)
	player.interact_requested.connect(_on_interact)
	player.noise_emitted.connect(_on_player_noise)

	# Phase 6: audio/haptic feedback layer (scene-owned, persists across
	# loads and restarts; single playback owner per event).
	feedback_manager = FeedbackManager.new()
	feedback_manager.name = "FeedbackManager"
	add_child(feedback_manager)

	# Phase 5: scene-owned mission coordinator (persists across loads).
	mission_manager = MissionManager.new()
	mission_manager.name = "MissionManager"
	add_child(mission_manager)
	mission_manager.mission_state_changed.connect(_on_mission_state_changed)
	mission_manager.mission_rejected.connect(_on_mission_rejected)
	mission_manager.objective_completed.connect(_on_objective_completed)
	mission_manager.extraction_availability_changed.connect(_on_extraction_availability)
	mission_manager.restricted_zone_changed.connect(_on_restricted_zone_changed)
	mission_manager.mission_succeeded.connect(_on_mission_succeeded)
	mission_manager.mission_failed.connect(_on_mission_failed)
	mission_manager.detection_warning.connect(_on_detection_warning)

	# Gameplay events -> feedback (single subscription each; restarts
	# never duplicate these connections because the managers persist).
	mission_manager.objective_completed.connect(
		func(_id): feedback_manager.play_event(&"terminal"); feedback_manager.request_haptic(80))

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

	# Camera confined to the generated map. Axis limits are applied only
	# when the map is at least viewport-sized on that axis - smaller maps
	# keep the engine default (effectively unlimited), which avoids
	# invalid/inverted limits while keeping the map fully visible.
	var camera: Camera2D = player.camera
	var bounds: Rect2 = level_data["bounds"]
	var viewport: Vector2 = get_viewport_rect().size
	if bounds.size.x >= viewport.x:
		camera.limit_left = 0
		camera.limit_right = int(bounds.size.x)
	else:
		camera.limit_left = -1000000
		camera.limit_right = 1000000
	if bounds.size.y >= viewport.y:
		camera.limit_top = 0
		camera.limit_bottom = int(bounds.size.y)
	else:
		camera.limit_top = -1000000
		camera.limit_bottom = 1000000
	camera.make_current()
	# Snap the smoothed view to the (possibly teleported) player so the
	# mission never starts with the player off-screen.
	camera.reset_smoothing()
	# Phase 7: cache keys that cannot legally persist across a level
	# load (state/zone/hint belong to the previous mission).
	_hud_cache["state"] = -1
	_hud_cache["zone"] = &""
	_hud_cache["hint"] = "__invalidate__"

	# Doors: registered so is_cell_blocked() tracks their live state.
	for door: Node in level_data["doors"]:
		StealthSystem.register_door(door)
		door.state_changed.connect(_on_door_state_changed)

	_spawn_lights(descriptor)
	_spawn_enemies()

	# Phase 5: fresh mission for the new level. Terminal completion flows
	# into the mission by stable id; duplicate ids are rejected there.
	for terminal in level_data["terminals"]:
		if is_instance_valid(terminal):
			terminal.completed.connect(mission_manager.on_terminal_completed)
	mission_manager.start_mission(level_data, level_data.get("zones", []))
	_interact_search_timer = 0.0
	_find_interact_target(true)

	print("SHADOW PROTOCOL: level '%s' generated (grid %s), player at %s, lights: %d, enemies: %d, mission: %d objective(s)" % [
		level_label, level_data["grid_size"], level_data["spawn"],
		StealthSystem.light_count(), enemies.size(),
		mission_manager.objectives_total()
	])


## Tears down the current level: enemies, lights and door registrations
## are removed before the next build; the player instance is reused.
func _clear_level() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
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
	# Phase 7 optimization: identical model, but the value is pushed to
	# the player/meter only when it actually changed - a stationary
	# player no longer re-emits unchanged signals every idle frame.
	var visibility: float = StealthSystem.compute_visibility(
		player.global_position, player.crouching, player.speed_ratio
	)
	if visibility != player.visibility:
		player.set_visibility(visibility)
		meter.set_value(visibility)

	# Phase 5: mission logic + throttled interaction-target search (the
	# full search is not needed every frame).
	mission_manager.update(delta, player.global_position, enemies,
		level_data.get("zones", []), level_data["cell_size"], level_data["origin"])
	# Phase 6: detection danger reads the REAL mission timer; ordinary
	# suspicion (enemy investigating noise) is shown separately and
	# never as confirmed detection.
	detection_meter.set_value(mission_manager.detection_ratio())
	var suspected: bool = false
	for enemy in enemies:
		if is_instance_valid(enemy) and (enemy is Enemy) \
		and (enemy.state == &"suspicious" or enemy.state == &"investigating"):
			suspected = true
			break
	detection_meter.set_suspected(suspected)
	_interact_search_timer -= delta
	if _interact_search_timer <= 0.0:
		_interact_search_timer = 0.25
		_find_interact_target(true)
	if Input.is_action_just_pressed("interact"):
		_on_interact()  # keyboard path shares the touch interaction handler
	if Input.is_action_just_pressed("restart"):
		restart_mission()
	_update_hud()
	if _status_timer > 0.0:
		_status_timer -= delta
		if _status_timer <= 0.0:
			status.text = ""


## Phase 7 optimization: the HUD text is rebuilt only when a tracked
## value actually changes (level, state, objectives, extraction, zone,
## hint) instead of every idle frame. Identical output; unchanged
## steady-state cost is a cheap comparison instead of a full string
## rebuild. The rebuild counter verifies the reduction.
var _hud_cache := {"label": "", "state": -1, "done": -1, "total": -1,
	"extract": false, "zone": &"", "hint": ""}


func _update_hud() -> void:
	var zone: StringName = LevelCatalog.zone_at(
		level_data.get("zones", []), player.global_position,
		level_data["cell_size"], level_data["origin"]
	)
	var extract_now: bool = mission_manager.extraction_available()
	if _hud_cache["label"] == level_label \
	and _hud_cache["state"] == mission_manager.state \
	and _hud_cache["done"] == mission_manager.objectives_done() \
	and _hud_cache["total"] == mission_manager.objectives_total() \
	and _hud_cache["extract"] == extract_now \
	and _hud_cache["zone"] == zone \
	and _hud_cache["hint"] == _hud_action_hint:
		return  # nothing visible changed: skip the rebuild entirely
	_hud_cache["label"] = level_label
	_hud_cache["state"] = mission_manager.state
	_hud_cache["done"] = mission_manager.objectives_done()
	_hud_cache["total"] = mission_manager.objectives_total()
	_hud_cache["extract"] = extract_now
	_hud_cache["zone"] = zone
	_hud_cache["hint"] = _hud_action_hint
	var state_names := {MissionManager.State.READY: "READY",
		MissionManager.State.ACTIVE: "ACTIVE", MissionManager.State.SUCCEEDED: "SUCCEEDED",
		MissionManager.State.FAILED: "FAILED"}
	hud.text = HUD_TEMPLATE % [
		level_label,
		state_names[mission_manager.state],
		mission_manager.objectives_done(),
		mission_manager.objectives_total(),
		"available" if extract_now else "locked",
		zone,
		_hud_action_hint,
	]
	if bench_enabled:
		bench_hud_rebuilds += 1


## Context-sensitive interaction (Phase 5): the single INTERACT action
## serves terminals and doors. Targets must be within interaction_radius
## and reachable by clear line of sight - walls and closed doors block
## context interaction. One press activates at most the single nearest
## eligible target (terminals win ties: deterministic).
func _on_interact() -> void:
	var target := _find_interact_target(false)
	if target == null:
		_show_status("Nothing to interact with here.")
		return
	if target is Terminal:
		if target.complete():
			# Mission progress + feedback flows through the
			# terminal.completed -> MissionManager.on_terminal_completed path.
			_show_status("Terminal %s accessed." % target.terminal_id)
		return
	if target is Door and not target.is_open:
		target.set_state(true)
		feedback_manager.play_event(&"door")
		feedback_manager.request_haptic(50)
		_show_status("Door opened.")


## Finds the nearest eligible interaction target. Terminals: state
## AVAILABLE, within radius, clear LOS. Doors: closed, within radius,
## clear LOS to just short of the door body. Returns null if none.
## Deterministic ordering: distance, then terminals before doors.
func _find_interact_target(update_hint: bool) -> Node:
	var best: Node = null
	var best_dist: float = -1.0
	var best_rank: int = 2
	if level_data.is_empty():
		return null
	for terminal in level_data["terminals"]:
		if not is_instance_valid(terminal) or not (terminal is Terminal) or terminal.is_completed():
			continue
		var d: float = player.global_position.distance_to(terminal.global_position)
		if d > interaction_radius:
			continue
		if not _los_clear_to(terminal.global_position, 0.0):
			continue
		if best == null or d < best_dist - 0.01 or (absf(d - best_dist) <= 0.01 and 1 < best_rank):
			best = terminal
			best_dist = d
			best_rank = 1
	for door in level_data.get("doors", []):
		if not is_instance_valid(door) or not (door is Door) or door.is_open:
			continue
		var dd: float = player.global_position.distance_to(door.global_position)
		if dd > interaction_radius:
			continue
		if not _los_clear_to(door.global_position, 30.0):
			continue
		if best == null or dd < best_dist - 0.01 or (absf(dd - best_dist) <= 0.01 and 2 < best_rank):
			best = door
			best_dist = dd
			best_rank = 2
	if update_hint:
		if best is Terminal:
			_hud_action_hint = "[E] Access terminal %s" % (best as Terminal).terminal_id
		elif best is Door:
			_hud_action_hint = "[E] Open door"
		else:
			_hud_action_hint = ""
	return best


## Physics line-of-sight check from the player to a target. Walls and
## closed doors block. [param stop_short] shortens the ray for door
## targets so the door's own body does not block its own interaction.
func _los_clear_to(target_pos: Vector2, stop_short: float) -> bool:
	var player_body := player as CollisionObject2D
	if player_body == null:
		return false
	var space := get_world_2d().direct_space_state
	var direction: Vector2 = (target_pos - player.global_position).normalized()
	var end: Vector2 = target_pos - direction * stop_short
	var exclude: Array[RID] = [player_body.get_rid()]
	var query := PhysicsRayQueryParameters2D.create(player.global_position, end, 1, exclude)
	query.collide_with_areas = false
	query.hit_from_inside = false
	var hit: Dictionary = space.intersect_ray(query)
	return hit.is_empty()


## Mission restart / replay: the Phase 4 level lifecycle rebuilds walls,
## doors (closed), terminals (AVAILABLE), enemies, lights and the
## player position, then a fresh mission starts. The selected layout
## descriptor is preserved; call load_level() with a different descriptor
## to start a distinct new mission on a new map.
func restart_mission() -> void:
	await load_level(current_descriptor)
	_hud_action_hint = ""
	detection_meter.set_value(0.0)
	detection_meter.set_suspected(false)
	_show_status("Mission restarted.")


func _on_mission_state_changed(_from_state: int, _to_state: int) -> void:
	pass


func _on_mission_rejected(reason: String) -> void:
	_show_status("Mission rejected: %s" % reason)


func _on_objective_completed(_terminal_id: StringName) -> void:
	pass  # progress feedback arrives via the next HUD update


func _on_extraction_availability(available: bool) -> void:
	if available:
		_show_status("All objectives complete. Extraction unlocked.")


func _on_restricted_zone_changed(zone_id: StringName) -> void:
	if zone_id != &"":
		_show_status("RESTRICTED ZONE - detection pressure doubled while detected here.")


func _on_mission_succeeded() -> void:
	_show_status("MISSION ACCOMPLISHED - press R to restart.")
	feedback_manager.play_event(&"success")
	feedback_manager.request_haptic(250)


func _on_mission_failed(reason: String) -> void:
	_show_status("MISSION FAILED (%s) - press R to restart." % reason)
	feedback_manager.play_event(&"failure")
	feedback_manager.request_haptic(300)


## Confirmed-contact onset (0) and critical pressure (1): edge-triggered
## by the mission manager, so warning audio never plays every frame.
func _on_detection_warning(level: int) -> void:
	feedback_manager.play_event(&"warning")
	feedback_manager.request_haptic(150 if level == 1 else 100)


## Player noise -> StealthSystem publication (with movement-state metadata).
func _on_player_noise(pos: Vector2, radius: float) -> void:
	StealthSystem.publish_noise(pos, radius, &"player", player.current_movement_state())


## Door state changes: patrol-route navigation data stays fresh - enemy
## routes are rebuilt so open doors become usable and closed ones avoided.
func _on_door_state_changed(is_open: bool) -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.set_patrol_route(_build_patrol_route(enemy.global_position))


## Future-HUD hook: state transitions surface as status feedback.
func _on_enemy_state(from_state: StringName, to_state: StringName) -> void:
	if to_state == &"alert":
		_show_status("DETECTED - an enemy has seen you!")


func _show_status(message: String) -> void:
	status.text = message
	_status_timer = 2.5
