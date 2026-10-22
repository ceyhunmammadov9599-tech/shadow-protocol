extends Node2D
## Shadow Protocol - main scene controller (Phase 1).
##
## Owns the level lifecycle: generates the test level from the grid, places
## the player, wires the touch controls and the StealthSystem autoload,
## runs the per-frame visibility update and the debug HUD.
##
## Later phases extend this file (enemy AI wiring, mission manager, audio),
## the responsibilities stay separated in their own scripts.

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

const HUD_TEMPLATE := "SHADOW PROTOCOL - Phase 1 build
Speed: %s px/s
Crouch: %s   Sprint: %s
Visibility: %s   Noise radius: %s px
Grid: %s
%s"

@onready var player: CharacterBody2D = $Player
@onready var level_root: Node2D = $LevelRoot
@onready var touch_layer: Control = $UI/TouchLayer
@onready var hud: Label = $UI/HUD
@onready var status: Label = $UI/Status

var level_data: Dictionary = {}
var _status_timer: float = 0.0


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

	print("SHADOW PROTOCOL: Phase 1 level generated (grid %s), player at %s" % [
		level_data["grid_size"], level_data["spawn"]
	])


func _process(delta: float) -> void:
	# Visibility model update (cheap: dictionary lookups only).
	var visibility: float = StealthSystem.compute_visibility(
		player.global_position, player.crouching, player.speed_ratio
	)
	player.set_visibility(visibility)
	_update_hud(visibility)
	if _status_timer > 0.0:
		_status_timer -= delta
		if _status_timer <= 0.0:
			status.text = ""


func _update_hud(visibility: float) -> void:
	hud.text = HUD_TEMPLATE % [
		"%.0f" % player.velocity.length(),
		"yes" if player.crouching else "no",
		"yes" if player.sprinting else "no",
		"%.0f%%" % (visibility * 100.0),
		"%.0f" % StealthSystem.noise_radius(player.crouching, player.speed_ratio, player.sprinting),
		"%s" % [level_data["grid_size"]],
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


func _show_status(message: String) -> void:
	status.text = message
	_status_timer = 2.5
