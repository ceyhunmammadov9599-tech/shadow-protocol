extends Node
var _ss: GDScript = load("res://scripts/stealth_system.gd")
## Shadow Protocol - Phase 7 device-free performance benchmark.
##
## Reproducible, scenario-based profiling harness. Runs the REAL game
## scene in representative situations and reports deterministic
## operation counters (AI ticks, vision rays, noise dispatches, HUD
## rebuilds) plus host timing. Repetitions and warmup are fixed.
##
## KNOWN LIMITATIONS (headless): the renderer is a dummy - render/draw
## statistics and any "FPS" numbers are UNAVAILABLE/meaningless here
## and are never reported as device performance. Host timings are
## wall-clock on the benchmark host, not Android numbers.
##
## Usage:
##   godot --headless --path . res://tools/benchmark.tscn

const SCENARIO_FRAMES: int = 600   # measured window (~10 s @ 60 Hz physics)
const WARMUP_FRAMES: int = 60
const REPETITIONS: int = 3

# Statics of class-named scripts are assigned via the class name.
# The autoload script (stealth_system.gd) has no class_name (it would
# collide with the autoload instance), so its script resource is
# loaded once at runtime and held in a var for static access.


func _ready() -> void:
	print("BENCH: godot=", Engine.get_version_info().string)
	print("BENCH: host-cores=", OS.get_processor_count(),
		" renderer=headless-dummy render-metrics=UNAVAILABLE")
	await _run_all()
	get_tree().quit()


func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().physics_frame


func _stress_descriptor() -> Dictionary:
	# Valid authored stress map, built on the real generator contract:
	# border walls, 8 enemy markers ('5'), spawn '4', terminal '3',
	# extraction '6', static lights '1'.
	var cols := 32
	var rows: Array[String] = []
	for y in range(12):
		var r := ""
		for x in range(cols):
			if x == 0 or x == cols - 1 or y == 0 or y == 11:
				r += "2"
			else:
				r += "0"
		rows.append(r)
	_mark(rows, 2, 1, "4")
	_mark(rows, 5, 2, "3")
	_mark(rows, 29, 9, "6")
	for cell in [[5, 2], [5, 8], [12, 4], [12, 7], [19, 3], [19, 8], [26, 4], [26, 7]]:
		if rows[cell[1]][cell[0]] == "0":
			_mark(rows, cell[0], cell[1], "5")
	_mark(rows, 9, 6, "1")
	_mark(rows, 22, 5, "1")
	return {"label": "stress8", "rows": rows, "zones": [], "moving_lights": []}


func _mark(rows: Array[String], x: int, y: int, ch: String) -> void:
	rows[y] = rows[y].substr(0, x) + ch + rows[y].substr(x + 1)


func _reset_counters() -> void:
	Enemy.bench_reset()
	_ss.bench_reset()
	Main.bench_reset()
	Player.bench_reset()


func _collect() -> Dictionary:
	return {
		"ai_ticks": Enemy.bench_decision_ticks,
		"fov_evals": Enemy.bench_fov_evals,
		"vision_rays": Enemy.bench_vision_rays,
		"noise_reactions": Enemy.bench_noise_reactions,
		"vis_computes": _ss.bench_visibility_computes,
		"noise_dispatches": _ss.bench_noise_dispatches,
		"light_queries": _ss.bench_light_queries,
		"hud_rebuilds": Main.bench_hud_rebuilds,
		"vis_sets": Player.bench_visibility_sets,
	}


func _scenario(label: String, descriptor: Dictionary, mode: String) -> Dictionary:
	var per_rep: Array[Dictionary] = []
	var node_count := 0
	for _rep in range(REPETITIONS):
		var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
		add_child(main)
		await _frames(2)
		await main.load_level(descriptor)
		await _frames(WARMUP_FRAMES)
		_reset_counters()
		var t0 := Time.get_ticks_usec()
		if mode == "move":
			Input.action_press("move_right")
			Input.action_press("sprint")
		elif mode == "detect":
			_mk_detect_fixture(main)
		elif mode == "door":
			(main.player as CharacterBody2D).global_position = Vector2(600.0, 216.0)
			main.interaction_radius = 320.0
			Input.action_press("interact")
			await _frames(2)
			Input.action_release("interact")
		await _frames(SCENARIO_FRAMES)
		var counters := _collect()
		counters["elapsed_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
		per_rep.append(counters)
		Input.action_release("move_right")
		Input.action_release("sprint")
		node_count = get_tree().get_node_count()
		main.queue_free()
		await _frames(12)
	var out := {"label": label}
	for key in per_rep[0]:
		if key == "elapsed_ms":
			var times: Array[float] = []
			for r in per_rep:
				times.append(r["elapsed_ms"])
			out["elapsed_ms"] = "%.0f/%.0f/%.0f" % [times.min(), (times[0] + times[1] + times[2]) / 3.0, times.max()]
		else:
			var total := 0
			for r in per_rep:
				total += r[key]
			out[key] = total / REPETITIONS
	out["nodes"] = node_count
	return out


func _mk_detect_fixture(main: Node) -> void:
	# Real architecture: a genuine enemy facing the player, exactly like
	# the smoke fixtures (no synthetic sensors, no disabled walls).
	var enemy: CharacterBody2D = (load("res://scenes/enemy.tscn") as PackedScene).instantiate()
	main.add_child(enemy)
	enemy.position = Vector2(72.0, 168.0)
	enemy.set_player(main.player)
	enemy.set_patrol_route([Vector2(72.0, 168.0)])
	enemy.ai_interval = 0.1
	enemy.facing = Vector2(0.0, -1.0)
	main.enemies.append(enemy)


func _restart_cycle() -> Dictionary:
	var timings: Array[float] = []
	var load_ms: Array[float] = []
	var restart_ms: Array[float] = []
	var switch_ms: Array[float] = []
	var nodes_after := 0
	for _rep in range(REPETITIONS):
		var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
		add_child(main)
		await _frames(2)
		var t0 := Time.get_ticks_usec()
		await main.load_level(LevelCatalog.default_descriptor())
		var t1 := Time.get_ticks_usec()
		await main.restart_mission()
		var t2 := Time.get_ticks_usec()
		await main.load_level(LevelCatalog.LAYOUT_B)
		var t3 := Time.get_ticks_usec()
		timings.append((t3 - t0) / 1000.0)
		load_ms.append((t1 - t0) / 1000.0)
		restart_ms.append((t2 - t1) / 1000.0)
		switch_ms.append((t3 - t2) / 1000.0)
		nodes_after = get_tree().get_node_count()
		main.queue_free()
		await _frames(12)
	return {
		"label": "H_restart_cycle",
		"load_ms": "%.0f/%.0f/%.0f" % [load_ms.min(), (load_ms[0] + load_ms[1] + load_ms[2]) / 3.0, load_ms.max()],
		"restart_ms": "%.0f/%.0f/%.0f" % [restart_ms.min(), (restart_ms[0] + restart_ms[1] + restart_ms[2]) / 3.0, restart_ms.max()],
		"switch_ms": "%.0f/%.0f/%.0f" % [switch_ms.min(), (switch_ms[0] + switch_ms[1] + switch_ms[2]) / 3.0, switch_ms.max()],
		"nodes_after": nodes_after,
	}


func _run_all() -> void:
	Enemy.bench_enabled = true
	_ss.bench_enabled = true
	Main.bench_enabled = true
	Player.bench_enabled = true

	var results: Array[Dictionary] = []
	# A. Legacy authored layout, steady state.
	results.append(await _scenario("A_legacy_steady", LevelCatalog.default_descriptor(), "idle"))
	# B. Authored layout B (doors, restricted depots).
	results.append(await _scenario("B_layout_b_steady", LevelCatalog.LAYOUT_B, "idle"))
	# C. Authored layout C (ring corridors).
	results.append(await _scenario("C_layout_c_steady", LevelCatalog.LAYOUT_C, "idle"))
	# D. Seeded procedural layout (seed preserved).
	results.append(await _scenario("D_seeded_7", LevelCatalog.generate_layout(7), "idle"))
	# E. Stress: valid authored rows, 8 real enemies.
	results.append(await _scenario("E_stress_8_enemies", _stress_descriptor(), "idle"))
	# F. Active visual detection (real enemy facing the player).
	results.append(await _scenario("F_detection_active", LevelCatalog.default_descriptor(), "detect"))
	# G. Player sprinting with camera + HUD active.
	results.append(await _scenario("G_movement_active", LevelCatalog.default_descriptor(), "move"))
	# I. Door interaction + moving lights (layout B door, legacy lights).
	results.append(await _scenario("I_door_active", LevelCatalog.LAYOUT_B, "door"))
	# H. Restart / level-switch cycle.
	var r_h := await _restart_cycle()

	for r in results:
		var parts: Array[String] = []
		for key in ["ai_ticks", "fov_evals", "vision_rays", "noise_reactions",
				"vis_computes", "noise_dispatches", "light_queries", "hud_rebuilds", "vis_sets"]:
			parts.append("%s=%d" % [key, r[key]])
		parts.append("elapsed_ms(min/mean/max)=%s" % r["elapsed_ms"])
		parts.append("nodes=%d" % r["nodes"])
		print("BENCH ", r["label"], ": ", ", ".join(parts))
	print("BENCH H_restart_cycle: ", JSON.stringify(r_h))

	Enemy.bench_enabled = false
	_ss.bench_enabled = false
	Main.bench_enabled = false
	Player.bench_enabled = false
