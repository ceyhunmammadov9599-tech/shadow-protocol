class_name MissionOverlay
extends Control
## Shadow Protocol - mission end-state presentation (visual upgrade).
##
## A single reusable panel shown ONLY from the real MissionManager
## terminal states (SUCCEEDED/FAILED), driven by Main's existing
## mission_succeeded / mission_failed handlers. Reset on restart and on
## every level load; the restart button is fully functional (emits
## restart_requested -> Main.restart_mission()). No nonfunctional
## continue button exists. Mouse-transparent except the button.

signal restart_requested()

const COLOR_PANEL := Color(0.045, 0.06, 0.09, 0.88)
const COLOR_SUCCESS := Color(0.32, 0.85, 0.45)
const COLOR_FAILURE := Color(0.92, 0.28, 0.30)
const COLOR_TEXT := Color(0.88, 0.90, 0.94)
const COLOR_TEXT_DIM := Color(0.62, 0.66, 0.72)
const PANEL_SIZE := Vector2(420.0, 150.0)

var _title: Label
var _subtitle: Label
var _restart_btn: Button
var _fade_tween: Tween = null
var _current_state: int = -1  # -1 hidden, 0 success, 1 failure


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Panel, centered.
	var panel := ColorRect.new()
	panel.name = "Panel"
	panel.color = COLOR_PANEL
	panel.size = PANEL_SIZE
	panel.position = Vector2(-PANEL_SIZE.x / 2.0, -PANEL_SIZE.y / 2.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := Control.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.size = PANEL_SIZE
	center.position = -PANEL_SIZE / 2.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.add_child(panel)
	# Accent strip on top of the panel.
	var accent := ColorRect.new()
	accent.name = "Accent"
	accent.color = COLOR_SUCCESS
	accent.size = Vector2(PANEL_SIZE.x, 3.0)
	panel.add_child(accent)
	# Title.
	_title = Label.new()
	_title.name = "Title"
	_title.text = ""
	_title.add_theme_font_size_override("font", 26)
	_title.modulate = COLOR_TEXT
	_title.position = Vector2(20.0, 26.0)
	_title.size = Vector2(PANEL_SIZE.x - 40.0, 36.0)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_title)
	# Subtitle.
	_subtitle = Label.new()
	_subtitle.name = "Subtitle"
	_subtitle.text = ""
	_subtitle.add_theme_font_size_override("font", 14)
	_subtitle.modulate = COLOR_TEXT_DIM
	_subtitle.position = Vector2(20.0, 70.0)
	_subtitle.size = Vector2(PANEL_SIZE.x - 40.0, 42.0)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_subtitle)
	# Functional restart button (keyboard R still works).
	_restart_btn = Button.new()
	_restart_btn.name = "RestartBtn"
	_restart_btn.text = "RESTART MISSION"
	_restart_btn.add_theme_font_size_override("font", 15)
	_restart_btn.position = Vector2(PANEL_SIZE.x / 2.0 - 90.0, 112.0)
	_restart_btn.size = Vector2(180.0, 30.0)
	_restart_btn.pressed.connect(func() -> void: restart_requested.emit())
	panel.add_child(_restart_btn)
	visible = false
	modulate = Color(1, 1, 1, 0)


func _notification(what: int) -> void:
	# Tween cleanup on teardown: no dangling tweens across reloads.
	if what == NOTIFICATION_PREDELETE and _fade_tween != null:
		_fade_tween.kill()
		_fade_tween = null


## Shows the success panel. Only called from the real mission_succeeded.
func show_success(objectives_done: int, objectives_total: int) -> void:
	_show(0, "MISSION COMPLETE",
		"Objectives %d/%d secured. Extraction successful." % [objectives_done, objectives_total],
		COLOR_SUCCESS)


## Shows the failure panel. Only called from the real mission_failed.
func show_failure(reason: String) -> void:
	_show(1, "MISSION FAILED",
		"Reason: %s. Retry when you are ready." % reason,
		COLOR_FAILURE)


## Hides instantly (restart / level load). Duplicate-safe.
func reset() -> void:
	_current_state = -1
	visible = false
	modulate = Color(1, 1, 1, 0)
	if _fade_tween != null:
		_fade_tween.kill()
		_fade_tween = null


func is_showing() -> bool:
	return visible


func shown_state() -> int:
	return _current_state if visible else -1


func _show(state: int, title: String, subtitle: String, accent_color: Color) -> void:
	_current_state = state
	_title.text = title
	_title.modulate = accent_color
	_subtitle.text = subtitle
	(get_node("Center/Panel/Accent") as ColorRect).color = accent_color
	visible = true
	if _fade_tween != null:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, 0.25)
