class_name MissionManager
extends Node
## Shadow Protocol - mission coordinator (Phase 5).
##
## Scene-owned by Main (created in Main._ready, persists across level
## loads; start_mission() resets ALL session state). One authoritative
## mission state machine:
##   READY    - no mission accepted yet (or the level had invalid mission
##              metadata and the mission was rejected)
##   ACTIVE   - objectives tracked, extraction locked until complete,
##              detection grace timer running
##   SUCCEEDED - mission accomplished (terminal); no further transitions
##   FAILED   - mission failed; no further transitions
##
## RULES (documented, deterministic):
## - Failure rule: sustained genuine visual contact with the player
##   (enemy can_see_player(): FOV + range + unobstructed raycast) fills
##   a detection timer. The timer RESETS TO ZERO the moment no enemy
##   genuinely sees the player. Ordinary suspicion, noise investigation
##   or last-known-position knowledge never fill the timer. While the
##   player stands inside a restricted zone, genuine contact fills the
##   timer at RESTRICTED_ZONE_RATE (2x) - restricted exposure increases
##   detection pressure. Timer >= detection_grace => FAILED("detected").
## - Success rule: extraction becomes available when every required
##   terminal id is completed; the mission succeeds only when the player
##   is within EXTRACTION_RADIUS of the extraction point while ACTIVE
##   and eligible. Reaching extraction early does nothing.
## - Transition safety: terminal/extraction events are accepted only in
##   ACTIVE; no success after failure, no failure after success.
## - Multiple enemies never multiply detection time: the timer advances
##   once per update regardless of how many enemies see the player.

signal mission_state_changed(from_state: int, to_state: int)
signal mission_rejected(reason: String)
signal objective_progress_changed(done_count: int, total_count: int)
signal objective_completed(terminal_id: StringName)
signal extraction_availability_changed(available: bool)
signal restricted_zone_changed(zone_id: StringName)
## Edge-triggered detection-pressure warnings: level 0 = confirmed
## visual contact onset, level 1 = contact reached half the grace
## period (critical). Never emitted per frame.
signal detection_warning(level: int)
signal mission_succeeded()
signal mission_failed(reason: String)

enum State { READY, ACTIVE, SUCCEEDED, FAILED }

const EXTRACTION_RADIUS: float = 60.0
const RESTRICTED_ZONE_RATE: float = 2.0

var state: int = State.READY
var detection_grace: float = 3.0  # configurable; seconds of sustained contact
var detection_timer: float = 0.0
var current_zone: StringName = &""
var extraction_position: Vector2 = Vector2(-99999.0, -99999.0)
var mission_active_layout_label: String = ""

var _required: Array[StringName] = []
var _completed: Dictionary = {}  # terminal_id -> true
var _extraction_available: bool = false
var _invalid_reason: String = ""
var _warned_detected: bool = false
var _warned_critical: bool = false


## Starts (or restarts) a mission from level data. Resets everything:
## objective records, detection timer, restricted-zone tracking,
## extraction lock. Invalid mission metadata (no extraction or no
## terminals) is REPORTED and rejected - the manager stays READY and
## can never grant success for it.
func start_mission(level_data: Dictionary, zones: Array) -> void:
	state = State.READY
	_required.clear()
	_completed.clear()
	_extraction_available = false
	_invalid_reason = ""
	detection_timer = 0.0
	_warned_detected = false
	_warned_critical = false
	current_zone = &""
	mission_active_layout_label = str(level_data.get("label", ""))

	var terminals: Array = level_data.get("terminals", [])
	var extraction: Variant = level_data.get("extraction", null)
	if extraction == null or not (extraction is Vector2):
		_invalid_reason = "missing extraction point"
		mission_rejected.emit(_invalid_reason)
		return
	if terminals.is_empty():
		_invalid_reason = "missing objective terminals"
		mission_rejected.emit(_invalid_reason)
		return
	extraction_position = extraction
	for terminal: Node in terminals:
		_required.append(terminal.terminal_id)
	_set_state(State.ACTIVE)
	objective_progress_changed.emit(0, _required.size())
	extraction_availability_changed.emit(false)


## True when [param terminal_id] is required and not yet completed.
func is_objective_pending(terminal_id: StringName) -> bool:
	return state == State.ACTIVE and _required.has(terminal_id) and not _completed.has(terminal_id)


## Objective completion by stable terminal id. Duplicate ids, unknown ids
## and events outside ACTIVE are ignored.
func on_terminal_completed(terminal_id: StringName) -> void:
	if state != State.ACTIVE:
		return
	if not _required.has(terminal_id) or _completed.has(terminal_id):
		return
	_completed[terminal_id] = true
	objective_completed.emit(terminal_id)
	objective_progress_changed.emit(_completed.size(), _required.size())
	if _completed.size() >= _required.size() and not _extraction_available:
		_extraction_available = true
		extraction_availability_changed.emit(true)


func objectives_done() -> int:
	return _completed.size()


func objectives_total() -> int:
	return _required.size()


func extraction_available() -> bool:
	return _extraction_available


func invalid_reason() -> String:
	return _invalid_reason


## Per-frame mission update. [param enemies] is Main's live enemy list;
## freed enemies are skipped safely.
func update(delta: float, player_pos: Vector2, enemies: Array, zones: Array, cell_size: float, origin: Vector2) -> void:
	if state != State.ACTIVE:
		return

	# Restricted-zone tracking: deterministic membership query, one
	# notification per zone change (never repeated per frame).
	var zone: StringName = LevelCatalog.zone_at(zones, player_pos, cell_size, origin)
	if zone != current_zone:
		current_zone = zone
		restricted_zone_changed.emit(zone)

	# Detection pressure: only genuine current visual contact counts.
	var genuinely_seen: bool = false
	for enemy in enemies:
		if is_instance_valid(enemy) and (enemy is Enemy) and enemy.can_see_player():
			genuinely_seen = true
			break
	if genuinely_seen:
		var rate: float = RESTRICTED_ZONE_RATE if current_zone != &"" else 1.0
		detection_timer += delta * rate
		if not _warned_detected:
			_warned_detected = true
			detection_warning.emit(0)
		if detection_timer >= detection_grace * 0.5 and not _warned_critical:
			_warned_critical = true
			detection_warning.emit(1)
	else:
		detection_timer = 0.0  # documented rule: full reset when contact ends
		_warned_detected = false
		_warned_critical = false
	if detection_timer >= detection_grace:
		_fail(&"detected")
		return

	# Extraction: only after all objectives, only by actually being
	# inside the extraction region.
	if _extraction_available and player_pos.distance_to(extraction_position) <= EXTRACTION_RADIUS:
		_set_state(State.SUCCEEDED)
		mission_succeeded.emit()


## Detection timer relative to the grace period (0..1), for HUD use.
func detection_ratio() -> float:
	if detection_grace <= 0.0:
		return 0.0
	return clampf(detection_timer / detection_grace, 0.0, 1.0)


func _fail(reason: StringName) -> void:
	_set_state(State.FAILED)
	mission_failed.emit(String(reason))


func _set_state(new_state: int) -> void:
	if state == new_state:
		return
	if state == State.SUCCEEDED or state == State.FAILED:
		return  # terminal states are final; no contradictory transitions
	var old: int = state
	state = new_state
	mission_state_changed.emit(old, new_state)
