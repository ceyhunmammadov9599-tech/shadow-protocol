class_name FeedbackManager
extends Node
## Shadow Protocol - audio/haptic feedback layer (Phase 6, P6-T2).
##
## Minimal, event-driven feedback: gameplay code calls play_event() /
## request_haptic() on genuine events only. This node owns:
## - Five procedurally synthesized short tones (AudioStreamWAV generated
##   in code: no external assets, no licensing ambiguity): terminal,
##   door, warning, success, failure.
## - One AudioStreamPlayer per sound: single playback owner per event,
##   no cross-subscription duplicate playback, no leaked players
##   (children of this node, freed with it and with the main scene).
## - A warning cooldown (WARNING_COOLDOWN) so sustained detection cannot
##   retrigger the alarm every frame.
## - A mute switch and a haptics switch.
##
## Haptics: request_haptic() separates the game event from the
## platform-dependent call. Accepted requests emit haptic_event (so
## device-free tests can verify routing); the actual
## Input.vibrate_handheld() call happens ONLY on a supported mobile
## platform (feature-checked), never in headless mode. A cooldown
## rate-limits repeated alerts. Actual hardware vibration is UNVERIFIED
## under the device-free protocol.

signal audio_played(event_name: StringName)
signal haptic_event(duration_ms: int)

const WARNING_COOLDOWN: float = 2.0
const HAPTIC_COOLDOWN: float = 0.6
const MIX_RATE: int = 22050
const VOLUME_DB: float = -6.0

## Runtime switches (tests and settings may toggle these).
var muted: bool = false
var haptics_enabled: bool = true

var _warning_cooldown_left: float = 0.0
var _haptic_cooldown_left: float = 0.0
var _players: Dictionary = {}  # event name -> AudioStreamPlayer


func _ready() -> void:
	var specs := {
		&"terminal": [660.0, 880.0, 0.12],
		&"door": [240.0, 200.0, 0.06],
		&"warning": [170.0, 130.0, 0.22],
		&"success": [523.0, 784.0, 0.25],
		&"failure": [330.0, 110.0, 0.35],
	}
	for event: StringName in specs:
		var player := AudioStreamPlayer.new()
		player.name = "Sfx" + String(event).capitalize()
		player.stream = _make_tone(specs[event][0], specs[event][1], specs[event][2])
		player.volume_db = VOLUME_DB
		add_child(player)
		_players[event] = player


func _process(delta: float) -> void:
	_warning_cooldown_left = maxf(0.0, _warning_cooldown_left - delta)
	_haptic_cooldown_left = maxf(0.0, _haptic_cooldown_left - delta)


## Plays the sound for a gameplay event. Returns false when muted or
## when the warning cooldown rejects a repeat; emits audio_played only
## for a genuinely started playback.
func play_event(event: StringName) -> bool:
	if muted or not _players.has(event):
		return false
	if event == &"warning":
		if _warning_cooldown_left > 0.0:
			return false
		_warning_cooldown_left = WARNING_COOLDOWN
	var player: AudioStreamPlayer = _players[event]
	player.play()
	audio_played.emit(event)
	return true


## Requests vibration feedback. Config and cooldown are checked before
## the platform call; on unsupported platforms (including every
## device-free/headless run) no hardware call is attempted, but accepted
## requests still emit haptic_event so routing stays testable.
func request_haptic(duration_ms: int) -> bool:
	if not haptics_enabled:
		return false
	if _haptic_cooldown_left > 0.0:
		return false
	_haptic_cooldown_left = HAPTIC_COOLDOWN
	haptic_event.emit(duration_ms)
	if OS.has_feature("android") or OS.has_feature("ios"):
		Input.vibrate_handheld(duration_ms)
	return true


## Synthesizes a short sine blip with exponential decay. Fully
## in-project: no external files, deterministic bytes.
func _make_tone(freq_start: float, freq_end: float, duration: float) -> AudioStreamWAV:
	var sample_count: int = int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var phase: float = 0.0
	for i in range(sample_count):
		var t: float = float(i) / float(sample_count)
		var freq: float = lerpf(freq_start, freq_end, t)
		phase += TAU * freq / float(MIX_RATE)
		var envelope: float = exp(-3.0 * t) * minf(1.0, t * 100.0)
		var sample: int = int(sin(phase) * envelope * 12000.0)
		data.encode_s16(i * 2, sample)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
