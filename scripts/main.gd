extends Node2D
## Shadow Protocol - main scene controller (Phases 1-2).
##
## Owns the level lifecycle: generates the test level from the grid, places
## the player, wires the touch controls, dynamic lights, the StealthSystem
## autoload, the visibility meter and the noise event pipeline, runs the
## per-frame visibility update and the debug HUD.

## Phase 1 test level (16 x 28). Values: 0 shadow floor, 1 lit floor,
## 2 wall, 3 terminal, 4 player spawn, 5 enemy spawn, 6 extraction.
## Verified: single marker of each type, every marker reachable from spawn.
const TEST_GRID: Array[String] = [
	"############################",
	"#4........#....1...#.....3.#",
	"#..............1...#.......#",
	"#.........#....1...#.......#",
	"#..####...#........#.###...#",
	"#..#..#...#..1111..#.#.#...#",
	"#..#..#...#..1..1..#.#.#...#",
	"#..#..#...#..1..1....#.#...#",
	"#..#..#...#..1111..#.#.#...#",
	"#..#..#...#........#.#.#...#",
	"#..####...#....1...#.###...#",
	"#.........#....1...#.......#",
	"#...5..........1.......6...#",
	"#.........#....1...#.......#",
	"#.........#....1...#.......#",
	"############################",
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

const HUD_TEMPLATE := "SHADOW PROTOCOL - Phase 2 build
Speed: %s px/s
Crouch: %s   Sprint: %s
Noise radius: %s px
Grid: %s   Lights: %s
%s"

@onready var player: CharacterBody2D = $Player
@onready var level_root: Node2D = $LevelRoot
@onready var touch_layer: Control = $UI/TouchLayer
@onready var hud: Label = $UI/HUD
@onready var status: Label = $UI/Status
@onready var meter: Control = $UI/VisibilityMeter

var level_data: Dictionary = {}
var _status_timer: float = 0.0
var _noise_events_seen: int = 0


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

	print("SHADOW PROTOCOL: Phase 2 level generated (grid %s), player at %s, lights: %d" % [
		level_data["grid_size"], level_data["spawn"], StealthSystem.light_count()
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


func _update_hud() -> void:
	hud.text = HUD_TEMPLATE % [
		"%.0f" % player.velocity.length(),
		"yes" if player.crouching else "no",
		"yes" if player.sprinting else "no",
		"%.0f" % StealthSystem.noise_radius(player.crouching, player.speed_ratio, player.sprinting),
		"%s" % [level_data["grid_size"]],
		"%d" % StealthSystem.light_count(),
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
