class_name MovingLight
extends LightSource
## Shadow Protocol - moving light source (ping-pong patrol between two
## points). Demonstrates and exercises dynamic light support: gameplay
## contribution updates live because StealthSystem reads global_position
## at query time. Deterministic (pure function of elapsed time).

@export var point_a: Vector2 = Vector2.ZERO
@export var point_b: Vector2 = Vector2.ZERO
@export_range(10.0, 400.0, 1.0) var speed: float = 80.0

var _elapsed: float = 0.0


func _process(delta: float) -> void:
	_elapsed += delta
	var span: Vector2 = point_b - point_a
	var length: float = span.length()
	if length < 0.01:
		return
	var period: float = (2.0 * length) / speed
	# Ping-pong phase 0..2 mapped to a triangle wave 0..1.
	var phase: float = fmod(_elapsed, period) / period * 2.0
	var t: float = phase if phase <= 1.0 else 2.0 - phase
	global_position = point_a.lerp(point_b, t)
