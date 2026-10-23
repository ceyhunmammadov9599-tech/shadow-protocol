class_name WarningLayer
extends Control
## Shadow Protocol - detection danger screen edges (visual upgrade).
##
## Four thin red edge rectangles whose alpha tracks the REAL
## MissionManager detection ratio (pushed from Main at the same point
## the DetectionMeter is updated). Calm = fully invisible; critical
## contact = clearly visible but restrained red framing. No continuous
## animation; updates only when the ratio meaningfully changes, so the
## idle cost is zero.

const COLOR_WARN := Color(0.92, 0.25, 0.28)
const EDGE_THICKNESS := 6.0
const MAX_ALPHA := 0.55
const UPDATE_EPSILON := 0.02

var _edges: Array[ColorRect] = []
var _last_ratio: float = -1.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 4:
		var edge := ColorRect.new()
		edge.name = "Edge%d" % i
		edge.color = COLOR_WARN
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(edge)
		_edges.append(edge)
	_layout_edges()
	get_viewport().size_changed.connect(_layout_edges)


func _layout_edges() -> void:
	if _edges.size() != 4:
		return
	var size_v := size
	_edges[0].position = Vector2.ZERO
	_edges[0].size = Vector2(size_v.x, EDGE_THICKNESS)
	_edges[1].position = Vector2(0.0, size_v.y - EDGE_THICKNESS)
	_edges[1].size = Vector2(size_v.x, EDGE_THICKNESS)
	_edges[2].position = Vector2.ZERO
	_edges[2].size = Vector2(EDGE_THICKNESS, size_v.y)
	_edges[3].position = Vector2(size_v.x - EDGE_THICKNESS, 0.0)
	_edges[3].size = Vector2(EDGE_THICKNESS, size_v.y)


func set_ratio(ratio: float) -> void:
	var clamped := clampf(ratio, 0.0, 1.0)
	if absf(clamped - _last_ratio) < UPDATE_EPSILON:
		return
	_last_ratio = clamped
	# Ratio 0.5 = grace half gone (meter CRITICAL) -> full warning frame.
	var alpha: float = clampf((clamped - 0.10) / 0.40, 0.0, 1.0) * MAX_ALPHA
	for edge in _edges:
		edge.color.a = alpha


func current_alpha() -> float:
	return _edges[0].color.a if not _edges.is_empty() else 0.0
