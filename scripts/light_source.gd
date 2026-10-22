class_name LightSource
extends PointLight2D
## Shadow Protocol - dynamic light source with gameplay-coupled parameters.
##
## The SAME parameters drive both the rendered light and the stealth model:
##   light_radius     gameplay hearing... illumination radius (pixels);
##                    also sets texture scale so the visual disk matches
##   light_intensity   0..1 gameplay strength; also sets light energy
##   enabled           toggles both rendering and gameplay contribution
##   global_position   live; lights may move freely (see MovingLight)
##
## StealthSystem queries these live each visibility evaluation, so a moving
## or disabled light changes gameplay instantly with no re-registration.
##
## DOCUMENTED APPROXIMATION: neither the rendered light nor the gameplay
## model implements wall occlusion (no LightOccluder2D, no raycasts).
## Lights are authored so their radius does not cross walls in the shipped
## level, and visual + gameplay stay consistent by sharing one model.
## This is a deterministic gameplay lighting model, not physically based
## shadow simulation.

@export_range(32.0, 1024.0, 1.0) var light_radius: float = 160.0
@export_range(0.05, 1.0, 0.01) var light_intensity: float = 0.8

const LAMP_COLOR := Color(1.0, 0.88, 0.62)


func _ready() -> void:
	# Programmatic radial gradient texture: no external asset required,
	# the visual disk edge lands exactly at light_radius.
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	gradient.offsets = PackedFloat32Array([0.0, 0.65])

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256

	self.texture = texture
	texture_scale = (light_radius * 2.0) / 256.0
	energy = light_intensity
	color = LAMP_COLOR
	# blend_mode defaults to additive for Light2D; no override needed.

	var stealth: Node = get_node_or_null("/root/StealthSystem")
	if stealth != null:
		stealth.register_light(self)
	else:
		push_warning("LightSource: StealthSystem autoload not available")


func _exit_tree() -> void:
	var stealth: Node = get_node_or_null("/root/StealthSystem")
	if stealth != null:
		stealth.unregister_light(self)


## Toggles the light for BOTH rendering and gameplay.
func set_light_enabled(active: bool) -> void:
	enabled = active


## Deterministic gameplay contribution of this light at [param world_pos].
## Quadratic falloff, zero beyond light_radius, nothing when disabled.
func contribution_at(world_pos: Vector2) -> float:
	if not enabled:
		return 0.0
	var distance: float = world_pos.distance_to(global_position)
	if distance >= light_radius:
		return 0.0
	var t: float = 1.0 - distance / light_radius
	return clampf(light_intensity * t * t, 0.0, 1.0)
