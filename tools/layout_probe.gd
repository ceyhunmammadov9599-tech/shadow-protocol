## Device-free layout diagnostic. Boots the real main scene under several
## landscape window sizes (reproducing the canvas_items/expand canvas the
## runtime sees), reloads the level so camera limits recompute per size, and
## reports viewport/bounds/camera geometry plus the exposed-margin fraction.
## Usage: godot --headless --path . -s tools/layout_probe.gd
extends SceneTree
const SIZES := [Vector2i(1280, 576), Vector2i(960, 540), Vector2i(1280, 720),
	Vector2i(1600, 900), Vector2i(2340, 1080)]
var frames := 0
var main: Node2D = null
var step := -1
func _probe(tag: String) -> void:
	var vp: Rect2 = main.get_viewport_rect()
	var cam: Camera2D = main.get_node("Player/Camera2D")
	var b: Rect2 = main.level_data["bounds"]
	var cam_center := cam.get_screen_center_position()
	var view := Rect2(cam_center - vp.size / 2.0, vp.size)
	var gray_left := 0.0
	if b.position.x >= view.position.x:
		gray_left = (b.position.x - view.position.x) / vp.size.x
	print("PROBE[", tag, "] canvas=", vp.size, " limits L=", cam.limit_left,
		" R=", cam.limit_right, " T=", cam.limit_top, " B=", cam.limit_bottom,
		" cam=", cam_center, " margin_left_frac=%.3f" % gray_left,
		" player_visible=", view.has_point(main.player.global_position))
func _process(_delta: float) -> bool:
	frames += 1
	if frames == 1:
		var ps: PackedScene = load("res://scenes/main.tscn")
		main = ps.instantiate()
		root.add_child(main)
		return false
	if step == -1 and frames >= 5:
		step = 0
		root.size = SIZES[0]
		return false
	# Each size needs: 1 frame for the canvas to resize, then a reload, then 2
	# frames for the reload to apply, then probe.
	if step < SIZES.size():
		var phase := (frames - 5) % 4
		if phase == 0 and step > 0:
			root.size = SIZES[step]
		if phase == 1:
			main.load_level(main.current_descriptor)
		if phase == 3:
			_probe("%dx%d" % [SIZES[step].x, SIZES[step].y])
			step += 1
			if step == SIZES.size():
				# Restart check: reload once more at the last size and verify
				# the camera does not jump between consecutive frames.
				return false
		return false
	# Restart stability: two probes two frames apart at the final size.
	if frames == _final_probe_frame():
		_probe("restart-check")
		quit()
	return false
func _final_probe_frame() -> int:
	return 5 + SIZES.size() * 4 + 2
