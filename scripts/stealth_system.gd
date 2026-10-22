extends Node
## StealthSystem (autoload).
##
## Deterministic, grid-based illumination and visibility model for Phase 1.
## Lighting data comes from the level generator (lit cells + grid metrics).
## Phase 2 extends this with dynamic light sources; the interface stays:
##   compute_visibility(world_pos, crouching, speed_ratio) -> 0.0..1.0
##   noise_radius(crouching, speed_ratio, sprinting) -> float
##
## This is a gameplay model, not a physically based light simulation.

const CELL_SHADOW_VALUE: float = 0.25
const CELL_LIT_VALUE: float = 1.0
const CROUCH_FACTOR: float = 0.55
const MOTION_VISIBILITY_BOOST: float = 0.15

const NOISE_RADIUS_CROUCHED: float = 90.0
const NOISE_RADIUS_WALKING: float = 220.0
const NOISE_RADIUS_SPRINT: float = 320.0

var lit_cells: Dictionary = {}  # Vector2i(grid_x, grid_y) -> true
var cell_size: float = 48.0
var grid_origin: Vector2 = Vector2.ZERO


## Called by Main once the level has been generated.
func configure(lit: Dictionary, size: float, origin: Vector2) -> void:
	lit_cells = lit
	cell_size = maxf(size, 1.0)
	grid_origin = origin


## Normalized visibility 0.0 (fully concealed) .. 1.0 (fully exposed).
## Factors: illumination of the occupied cell, crouch posture, motion.
func compute_visibility(world_pos: Vector2, crouching: bool, speed_ratio: float) -> float:
	var value: float = CELL_LIT_VALUE if lit_cells.has(world_to_grid(world_pos)) else CELL_SHADOW_VALUE
	if crouching:
		value *= CROUCH_FACTOR
	value += MOTION_VISIBILITY_BOOST * clampf(speed_ratio, 0.0, 1.0)
	return clampf(value, 0.0, 1.0)


## Radius (pixels) of the noise a player in this state generates.
func noise_radius(crouching: bool, speed_ratio: float, sprinting: bool = false) -> float:
	if crouching:
		return NOISE_RADIUS_CROUCHED
	if sprinting:
		return NOISE_RADIUS_SPRINT
	return NOISE_RADIUS_WALKING * (0.55 + 0.45 * clampf(speed_ratio, 0.0, 1.0))


func world_to_grid(world_pos: Vector2) -> Vector2i:
	var local: Vector2 = (world_pos - grid_origin) / cell_size
	return Vector2i(int(floor(local.x)), int(floor(local.y)))


func grid_to_world(cell: Vector2i) -> Vector2:
	return grid_origin + Vector2(cell) * cell_size
