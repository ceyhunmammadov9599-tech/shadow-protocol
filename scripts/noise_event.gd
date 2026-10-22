class_name NoiseEvent
extends RefCounted
## Shadow Protocol - reusable noise event contract.
##
## Produced by StealthSystem.publish_noise() from player (and later,
## environmental) noise sources. Phase 3 enemy AI subscribes to
## StealthSystem.noise_emitted and consumes these events without ever
## needing to modify the player controller.

## World position where the sound originated.
var position: Vector2 = Vector2.ZERO
## Effective hearing radius in pixels.
var radius: float = 0.0
## Identifier of the emitting source ("player", future: "camera", ...).
var source_id: StringName = &""
## Movement state that generated the noise: "crouch", "walk", "sprint", "still".
var movement_state: StringName = &""
## Engine frame at emission time (deduplication and ordering aid).
var frame: int = -1
## Optional extra metadata for future consumers (never required).
var extra: Dictionary = {}


func setup(p_position: Vector2, p_radius: float, p_source_id: StringName,
		p_movement_state: StringName, p_frame: int) -> void:
	position = p_position
	radius = p_radius
	source_id = p_source_id
	movement_state = p_movement_state
	frame = p_frame


func to_string_repr() -> String:
	return "NoiseEvent(pos=%s radius=%.0f source=%s state=%s frame=%d)" % [
		position, radius, source_id, movement_state, frame]
