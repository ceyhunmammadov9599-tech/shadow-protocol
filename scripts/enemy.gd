class_name Enemy
extends CharacterBody2D
## Shadow Protocol - enemy guard with a six-state AI (Phase 3).
##
## States (named StringName constants, explicit transitions):
##   PATROL        deterministic waypoint loop, collision-aware movement
##   SUSPICIOUS    partial evidence noticed; stands, faces evidence,
##                 suspicion keeps accumulating (no instant alert)
##   INVESTIGATING moves toward a heard noise position (bounded)
##   ALERT         confirmed visual contact; chases live player position
##                 ONLY while visible; otherwise anchored to the last
##                 known position
##   SEARCHING     bounded search around the last known position /
##                 last sound position; never reads the hidden player
##   RETURNING     walks back to the nearest patrol waypoint, resumes
##                 PATROL on arrival
##
## Architecture (P3-T4): movement runs every physics frame; decisions
## (vision raycast, suspicion math, state transitions, target selection)
## run on a configurable throttled interval (ai_interval). Noise events
## arrive via StealthSystem.noise_emitted (P3-T3) - the player controller
## is never modified for consumers.
##
## DOCUMENTED APPROXIMATIONS (intentional, Phase 3 scope):
##   - Hearing is simple radial distance: heard when
##     distance(enemy, event.pos) <= event.radius * hearing_sensitivity.
##     No wall-based acoustic propagation.
##   - Detection strength is a tunable gameplay model (see
##     detection_strength()), not a physical sensor simulation.

signal state_changed(from_state: StringName, to_state: StringName)

const STATE_PATROL: StringName = &"patrol"
const STATE_SUSPICIOUS: StringName = &"suspicious"
const STATE_INVESTIGATING: StringName = &"investigating"
const STATE_ALERT: StringName = &"alert"
const STATE_SEARCHING: StringName = &"searching"
const STATE_RETURNING: StringName = &"returning"

# ---- tunable detection model ------------------------------------------------
@export_range(64.0, 2048.0, 1.0) var vision_range: float = 340.0
@export_range(20.0, 360.0, 1.0) var fov_degrees: float = 100.0
## Fraction of vision_range within which detection never falls below
## close_range_floor_strength (believable close-quarters behavior).
@export_range(0.05, 0.9, 0.05) var close_range_fraction: float = 0.25
@export_range(0.0, 1.0, 0.05) var close_range_floor_strength: float = 0.3

# ---- suspicion thresholds ---------------------------------------------------
@export_range(0.05, 5.0, 0.05) var suspicion_suspicious_threshold: float = 0.3
@export_range(0.1, 10.0, 0.1) var suspicion_alert_threshold: float = 1.0
@export_range(0.1, 10.0, 0.1) var suspicion_gain_per_sec: float = 1.6
@export_range(0.05, 5.0, 0.05) var suspicion_decay_per_sec: float = 0.45
@export_range(0.05, 10.0, 0.05) var lose_target_timeout: float = 0.8
@export_range(0.2, 30.0, 0.1) var search_duration: float = 3.0
@export_range(0.2, 30.0, 0.1) var investigate_timeout: float = 6.0
@export_range(0.1, 10.0, 0.1) var investigate_dwell: float = 1.2
@export_range(0.0, 3.0, 0.1) var hearing_sensitivity: float = 1.0

# ---- movement ---------------------------------------------------------------
@export_range(20.0, 400.0, 1.0) var patrol_speed: float = 110.0
@export_range(20.0, 400.0, 1.0) var investigate_speed: float = 140.0
@export_range(20.0, 500.0, 1.0) var chase_speed: float = 210.0

# ---- AI scheduling (P3-T4) --------------------------------------------------
@export_range(0.02, 1.0, 0.01) var ai_interval: float = 0.1

# Phase 7 benchmarking: static counters, enabled only by the benchmark
# harness. Zero behavior change; increments are plain integer adds.
static var bench_enabled: bool = false
static var bench_decision_ticks: int = 0
static var bench_fov_evals: int = 0
static var bench_vision_rays: int = 0
static var bench_noise_reactions: int = 0


static func bench_reset() -> void:
	bench_decision_ticks = 0
	bench_fov_evals = 0
	bench_vision_rays = 0
	bench_noise_reactions = 0
## Number of decision ticks executed (test observability for throttling).
var decision_ticks: int = 0

var state: StringName = STATE_PATROL
var suspicion: float = 0.0
var facing: Vector2 = Vector2.RIGHT
var enemy_id: StringName = &"enemy"
var player = null  # typed duck-access: CharacterBody2D (visibility, get_rid)

var last_known_player_position: Vector2 = Vector2.ZERO
var last_sound_position: Vector2 = Vector2.ZERO

var _patrol_route: Array[Vector2] = []
var _patrol_index: int = 0
var _target: Vector2 = Vector2.ZERO
var _state_timer: float = 0.0
var _arrived: bool = false
var _search_center: Vector2 = Vector2.ZERO
var _search_probe_index: int = 0
var _investigation_score: float = 0.0
var _ai_accum: float = 0.0
var _stealth: Node = null
var _noise_connected: bool = false

const SEARCH_PROBES: Array[Vector2] = [
	Vector2(0, 0), Vector2(56, 0), Vector2(0, 56), Vector2(-56, 0), Vector2(0, -56),
]
const STATE_COLORS: Dictionary = {
	STATE_PATROL: Color(0.62, 0.65, 0.72),
	STATE_SUSPICIOUS: Color(0.95, 0.78, 0.25),
	STATE_INVESTIGATING: Color(0.95, 0.55, 0.2),
	STATE_ALERT: Color(0.92, 0.28, 0.28),
	STATE_SEARCHING: Color(0.75, 0.35, 0.85),
	STATE_RETURNING: Color(0.45, 0.75, 0.9),
}


func _ready() -> void:
	_stealth = get_node_or_null("/root/StealthSystem")
	if _stealth != null:
		_stealth.noise_emitted.connect(_on_noise_event)
		_noise_connected = true
	_target = global_position
	_update_visual_state()


func _exit_tree() -> void:
	# Safe subscription cleanup (P3-T3 / P3-T4): enemies removed from the
	# tree never leak connections to the autoload.
	if _noise_connected and _stealth != null:
		_stealth.noise_emitted.disconnect(_on_noise_event)
		_noise_connected = false


# ------------------------------------------------------------- public setup --

func set_player(p: Node2D) -> void:
	player = p


func set_enemy_id(id: StringName) -> void:
	enemy_id = id


func set_patrol_route(route: Array) -> void:
	_patrol_route.clear()
	for point in route:
		_patrol_route.append(point)
	_patrol_index = 0
	if _patrol_route.size() > 0:
		_target = _patrol_route[0]


func current_target() -> Vector2:
	return _target


func patrol_route() -> Array[Vector2]:
	return _patrol_route.duplicate()


func last_known_position() -> Vector2:
	return last_known_player_position


func last_sound_target() -> Vector2:
	return last_sound_position


# ------------------------------------------------------------- detection -----

## True when the player is inside range + FOV and no solid geometry
## obstructs the line of sight. Walls block detection; lighting never
## bypasses physical obstruction (Phase 3 rule).
func can_see_player() -> bool:
	return detection_strength() > 0.0


## Detection strength 0..1 for the current frame (0 = not visible).
## Model: player visibility coefficient (Phase 2 StealthSystem value,
## already includes lighting, crouch and motion) scaled by distance;
## a close-range floor keeps point-blank detection believable and tunable.
func detection_strength() -> float:
	if not is_instance_valid(player):
		return 0.0
	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()
	if bench_enabled:
		bench_fov_evals += 1
	if dist > vision_range:
		return 0.0
	if dist > 0.001:
		var direction := to_player / dist
		var half_fov: float = deg_to_rad(fov_degrees * 0.5)
		# Boundary-safe comparison with an epsilon tolerance.
		if facing.dot(direction) < cos(half_fov) - 1e-6:
			return 0.0
	if _obstructed_to_player():
		return 0.0
	var distance_factor: float = 1.0 - 0.5 * clampf(dist / maxf(vision_range, 1.0), 0.0, 1.0)
	var strength: float = player.visibility * distance_factor
	if dist <= vision_range * close_range_fraction:
		strength = maxf(strength, close_range_floor_strength)
	return clampf(strength, 0.0, 1.0)


## Physics raycast from the enemy to the player. Any solid hit (walls are
## the only static colliders on layer 1) means blocked line of sight.
func _obstructed_to_player() -> bool:
	var player_body := player as CollisionObject2D
	if player_body == null:
		return false  # no physics body: nothing can obstruct
	var space := get_world_2d().direct_space_state
	var exclude: Array[RID] = [get_rid(), player_body.get_rid()]
	if bench_enabled:
		bench_vision_rays += 1
	var query := PhysicsRayQueryParameters2D.create(
		global_position, player.global_position, 1, exclude)
	query.hit_from_inside = false
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)
	return not hit.is_empty()


# ------------------------------------------------------------ noise events ---

## Noise reaction (P3-T3). Deterministic priority rules:
##   1. ALERT ignores noise entirely (confirmed visual contact wins).
##   2. Noise from this enemy's own id is ignored.
##   3. Out-of-range events are ignored (radial approximation).
##   4. A duplicate investigation target (< 24 px away) does not restart
##      the current investigation.
##   5. A competing stimulus only redirects an ongoing investigation or
##      search when its score (radius - distance) clearly exceeds the
##      current one (+ 40 px margin) - weak distant noise never
##      interrupts patrol or investigation.
func _on_noise_event(event: NoiseEvent) -> void:
	if bench_enabled and state != STATE_ALERT and event.source_id != enemy_id:
		bench_noise_reactions += 1
	if state == STATE_ALERT:
		return
	if event.source_id == enemy_id:
		return
	var dist: float = global_position.distance_to(event.position)
	if dist > event.radius * hearing_sensitivity:
		return
	if state == STATE_INVESTIGATING or state == STATE_SEARCHING:
		if event.position.distance_to(last_sound_position) < 24.0:
			return  # duplicate target: no reset
		var score: float = event.radius - dist
		if score <= _investigation_score + 40.0:
			return  # not compelling enough to redirect
	last_sound_position = event.position
	_investigation_score = event.radius - dist
	_enter_state(STATE_INVESTIGATING)


# ------------------------------------------------------ state machine core ---

func _enter_state(new_state: StringName) -> void:
	var old: StringName = state
	var is_redirect: bool = new_state == state  # same-state noise retarget
	state = new_state
	_state_timer = 0.0
	_arrived = false
	match new_state:
		STATE_PATROL:
			_target = _patrol_route[_patrol_index] if _patrol_route.size() > 0 else global_position
		STATE_SUSPICIOUS:
			_target = global_position  # stand and observe
		STATE_INVESTIGATING:
			_target = last_sound_position
		STATE_ALERT:
			_target = player.global_position if is_instance_valid(player) else last_known_player_position
		STATE_SEARCHING:
			# Search where the evidence was last credible: the player's last
			# known position when contact was lost visually, otherwise the
			# last heard sound position.
			_search_center = last_known_player_position if old == STATE_ALERT else last_sound_position
			_search_probe_index = 0
			_target = _search_center + SEARCH_PROBES[0]
		STATE_RETURNING:
			_target = _nearest_patrol_point()
	if not is_redirect:
		_update_visual_state()
		state_changed.emit(old, new_state)


## Decision update, executed only on the throttled AI interval (P3-T4).
## dt is the decision interval, not the physics delta.
func _decide(dt: float) -> void:
	if bench_enabled:
		bench_decision_ticks += 1
	var strength: float = detection_strength()
	var sees_player: bool = strength > 0.0
	if sees_player:
		# Only while genuinely visible is the live position learned.
		last_known_player_position = player.global_position
		suspicion += suspicion_gain_per_sec * strength * dt
		suspicion = clampf(suspicion, 0.0, suspicion_alert_threshold * 2.0)
	else:
		suspicion = maxf(0.0, suspicion - suspicion_decay_per_sec * dt)

	# Sight-based transitions take priority over noise-driven ones.
	if suspicion >= suspicion_alert_threshold and state != STATE_ALERT:
		_enter_state(STATE_ALERT)

	match state:
		STATE_PATROL:
			if _arrived_at(_target):
				_advance_patrol()
			if suspicion >= suspicion_suspicious_threshold:
				_enter_state(STATE_SUSPICIOUS)
		STATE_SUSPICIOUS:
			if suspicion >= suspicion_alert_threshold:
				_enter_state(STATE_ALERT)
			elif suspicion < suspicion_suspicious_threshold:
				_enter_state(STATE_RETURNING)
		STATE_INVESTIGATING:
			if suspicion >= suspicion_alert_threshold:
				_enter_state(STATE_ALERT)
			elif _arrived_at(last_sound_position):
				# Arrived at the sound: brief scan, then a bounded search.
				if _state_timer >= investigate_dwell:
					_enter_state(STATE_SEARCHING)
			elif _state_timer >= investigate_timeout:
				_enter_state(STATE_SEARCHING)
		STATE_ALERT:
			if is_instance_valid(player):
				# Phase 7: reuse the strength already computed at the top
				# of _decide() this tick - identical value, half the vision
				# evaluations during active pursuit.
				if strength > 0.0:
					_target = player.global_position  # chase live position
					_state_timer = 0.0  # visible: reset lost-contact timer
				else:
					# Lost sight: never track the hidden player. Anchor to
					# the last known position until the timeout expires.
					_target = last_known_player_position
					if _state_timer >= lose_target_timeout:
						_enter_state(STATE_SEARCHING)
		STATE_SEARCHING:
			if suspicion >= suspicion_alert_threshold:
				_enter_state(STATE_ALERT)
			elif _arrived_at(_target):
				_search_probe_index = (_search_probe_index + 1) % SEARCH_PROBES.size()
				_target = _search_center + SEARCH_PROBES[_search_probe_index]
			if _state_timer >= search_duration:
				_enter_state(STATE_RETURNING)
		STATE_RETURNING:
			if suspicion >= suspicion_alert_threshold:
				_enter_state(STATE_ALERT)
			elif suspicion >= suspicion_suspicious_threshold:
				_enter_state(STATE_SUSPICIOUS)
			elif _arrived_at(_target):
				_enter_state(STATE_PATROL)


func _advance_patrol() -> void:
	if _patrol_route.size() == 0:
		_target = global_position
		return
	_patrol_index = (_patrol_index + 1) % _patrol_route.size()
	_target = _patrol_route[_patrol_index]


func _nearest_patrol_point() -> Vector2:
	if _patrol_route.size() == 0:
		return global_position
	var nearest: Vector2 = _patrol_route[0]
	var best: float = global_position.distance_to(nearest)
	for point: Vector2 in _patrol_route:
		var d: float = global_position.distance_to(point)
		if d < best:
			best = d
			nearest = point
	return nearest


func _arrived_at(point: Vector2) -> bool:
	return global_position.distance_to(point) < 16.0


# -------------------------------------------------------- movement + loop ---

func _speed_for_state() -> float:
	match state:
		STATE_ALERT:
			return chase_speed
		STATE_INVESTIGATING, STATE_SEARCHING:
			return investigate_speed
		_:
			return patrol_speed


func _physics_process(delta: float) -> void:
	_state_timer += delta
	# Movement runs every physics frame (never throttled away).
	var to_target: Vector2 = _target - global_position
	if to_target.length() > 2.0:
		var desired_velocity: Vector2 = to_target.normalized() * _speed_for_state()
		velocity = velocity.lerp(desired_velocity, clampf(delta * 10.0, 0.0, 1.0))
	else:
		velocity = velocity.lerp(Vector2.ZERO, clampf(delta * 12.0, 0.0, 1.0))
	move_and_slide()
	if velocity.length() > 5.0:
		facing = velocity.normalized()
	var cone := get_node_or_null("FacingCone") as Node2D
	if cone != null:
		cone.rotation = facing.angle()
	# Throttled decision scheduling (P3-T4).
	_ai_accum += delta
	while _ai_accum >= ai_interval:
		_ai_accum -= ai_interval
		decision_ticks += 1
		_decide(ai_interval)


func _update_visual_state() -> void:
	var body := get_node_or_null("Body") as Polygon2D
	if body != null:
		body.color = STATE_COLORS.get(state, Color.WHITE)
	queue_redraw()
