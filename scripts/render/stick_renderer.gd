class_name StickRenderer
extends Node2D

var definition: RigDefinition
var pose: RigPose
var palette_color: Color = Color("#FF6600")
var head_hollow: bool = true

var _stroke: Line2D
var _head: StickHead
var _view_scale: float = 1.25


func setup(p_definition: RigDefinition, palette: Dictionary, palette_name: String,
		dpi_scale: float) -> void:
	definition = p_definition
	_view_scale = definition.base_scale * dpi_scale
	scale = Vector2.ONE * _view_scale
	_stroke = Line2D.new()
	_stroke.name = "Stroke"
	_stroke.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_stroke.end_cap_mode = Line2D.LINE_CAP_ROUND
	_stroke.joint_mode = Line2D.LINE_JOINT_ROUND
	_stroke.antialiased = true
	_stroke.round_precision = 8
	_stroke.width = definition.line_width
	add_child(_stroke)
	_head = StickHead.new()
	_head.name = "HeadCircle"
	_head.z_index = 20
	add_child(_head)
	set_palette(palette, palette_name)


func set_palette(palette: Dictionary, palette_name: String) -> void:
	var entries: Dictionary = palette.get("palettes", {})
	if not entries.has(palette_name):
		return
	var entry: Dictionary = entries[palette_name]
	palette_color = Color(str(entry.get("color", "#FF6600")))
	head_hollow = str(entry.get("head", "filled")) == "hollow"
	_stroke.default_color = palette_color
	_head.configure(definition.head_radius, palette_color, head_hollow,
			definition.head_line_width)


func sync(p_pose: RigPose) -> void:
	if definition == null or p_pose == null:
		return
	pose = p_pose
	position = pose.root_pos
	_stroke.points = _build_path(pose)
	var neck := pose.joint_pos[int(definition.joint_index[&"neck_top"])]
	_head.position = neck - pose.root_pos + Vector2(0.0, -definition.head_radius)


func _build_path(p: RigPose) -> PackedVector2Array:
	var points: Array[Vector2] = []
	_append(points, p, &"hand_l")
	_append(points, p, &"elbow_l")
	_append(points, p, &"chest")
	_append(points, p, &"neck_top")
	_append(points, p, &"chest")
	_append(points, p, &"pelvis")
	_append(points, p, &"knee_l")
	_append(points, p, &"ankle_l")
	_append(points, p, &"knee_l")
	_append(points, p, &"pelvis")
	_append(points, p, &"knee_r")
	_append(points, p, &"ankle_r")
	_append(points, p, &"knee_r")
	_append(points, p, &"pelvis")
	_append(points, p, &"chest")
	_append(points, p, &"elbow_r")
	_append(points, p, &"hand_r")
	return PackedVector2Array(points)


func _append(points: Array[Vector2], p: RigPose, joint: StringName) -> void:
	var index := int(definition.joint_index.get(joint, -1))
	if index >= 0:
		points.append(p.joint_pos[index] - p.root_pos)


func set_view_scale(value: float) -> void:
	_view_scale = value
	scale = Vector2.ONE * _view_scale


func get_view_scale() -> float:
	return _view_scale


func get_stroke_point_count() -> int:
	return _stroke.points.size() if _stroke != null else 0


func get_stroke_points() -> PackedVector2Array:
	return _stroke.points if _stroke != null else PackedVector2Array()


func get_stroke_width() -> float:
	return _stroke.width if _stroke != null else 0.0


func set_line_width(value: float) -> void:
	if _stroke != null:
		_stroke.width = value
	if _head != null:
		_head.line_width = value
		_head.queue_redraw()
