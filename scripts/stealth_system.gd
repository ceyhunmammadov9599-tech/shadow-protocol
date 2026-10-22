extends Node
## StealthSystem (autoload).
##
## Single coordination point for stealth gameplay:
##   - visibility model (Phase 2): static grid illumination combined with
##     dynamic LightSource contributions, posture and motion factors
##   - noise model (Phase 2): publish_noise() -> noise_emitted(NoiseEvent)
##     so Phase 3 enemy AI can subscribe without touching the player
##
## The illumination model is deterministic and headless-testable. It is a
## gameplay model: lights use quadratic distance falloff with no wall
## occlusion (documented in light_source.gd); grid cells 0/1 remain the
## static base layer from Phase 1.

signal noise_emitted(event: NoiseEvent)

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

## Registered dynamic light sources (LightSource and subclasses).
var _lights: Array[Node] = []
## source_id -> frame of its last published noise event (dedup).
var _last_noise_frame: Dictionary = {}


## Called by Main once the level has been generated.
func configure(lit: Dictionary, size: float, origin: Vector2) -> void:
	lit_cells = lit
	cell_size = maxf(size, 1.0)
	grid_origin = origin


# ---------------------------------------------------------------- lights --

func register_light(light: Node) -> void:
	if not _lights.has(light):
		_lights.append(light)


func unregister_light(light: Node) -> void:
	_lights.erase(light)


func light_count() -> int:
	return _lights.size()


## Total contribution of all enabled dynamic lights at a position.
## Additive with a hard clamp at 1.0: overlapping lights combine
## predictably and can never push illumination out of range.
func dynamic_light_at(world_pos: Vector2) -> float:
	var total: float = 0.0
	for light: Node in _lights:
		total += light.contribution_at(world_pos)
	return clampf(total, 0.0, 1.0)


# ---------------------------------------------------------- illumination --

## Static grid layer only (0 = shadow 0.25, 1 = lit 1.0).
func grid_illumination_at(world_pos: Vector2) -> float:
	return CELL_LIT_VALUE if lit_cells.has(world_to_grid(world_pos)) else CELL_SHADOW_VALUE


## Combined illumination: max() of the static grid layer and the dynamic
## light layer. max() keeps the two layers from double-counting the same
## exposure - a spotlamp over shadow tiles raises illumination, a lamp
## over an already-lit cell cannot exceed fully lit.
func illumination_at(world_pos: Vector2) -> float:
	return maxf(grid_illumination_at(world_pos), dynamic_light_at(world_pos))


## Normalized visibility 0.0 (fully concealed) .. 1.0 (fully exposed).
## Motion boost is applied exactly once, after the illumination and
## posture factors, and the result is clamped.
func compute_visibility(world_pos: Vector2, crouching: bool, speed_ratio: float) -> float:
	var value: float = illumination_at(world_pos)
	if crouching:
		value *= CROUCH_FACTOR
	value += MOTION_VISIBILITY_BOOST * clampf(speed_ratio, 0.0, 1.0)
	return clampf(value, 0.0, 1.0)


# ------------------------------------------------------------------ noise --

## Radius (pixels) of the noise a player in this state generates.
func noise_radius(crouching: bool, speed_ratio: float, sprinting: bool = false) -> float:
	if crouching:
		return NOISE_RADIUS_CROUCHED
	if sprinting:
		return NOISE_RADIUS_SPRINT
	return NOISE_RADIUS_WALKING * (0.55 + 0.45 * clampf(speed_ratio, 0.0, 1.0))


## Central noise publication point. Deduplicates same-source events
## inside one frame, then emits a NoiseEvent for any listener
## (Phase 3 enemies subscribe here - the player controller stays
## decoupled and is never modified for consumers).
func publish_noise(pos: Vector2, radius: float, source_id: StringName,
		movement_state: StringName = &"walk", extra: Dictionary = {}) -> void:
	var frame: int = Engine.get_process_frames()
	if _last_noise_frame.get(source_id, -1) == frame:
		return  # duplicate within the same frame: drop
	_last_noise_frame[source_id] = frame
	var event := NoiseEvent.new()
	event.setup(pos, radius, source_id, movement_state, frame)
	event.extra = extra
	noise_emitted.emit(event)


# ------------------------------------------------------------ conversion --

func world_to_grid(world_pos: Vector2) -> Vector2i:
	var local: Vector2 = (world_pos - grid_origin) / cell_size
	return Vector2i(int(floor(local.x)), int(floor(local.y)))


func grid_to_world(cell: Vector2i) -> Vector2:
	return grid_origin + Vector2(cell) * cell_size
