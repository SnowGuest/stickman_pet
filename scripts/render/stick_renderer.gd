class_name StickRenderer
extends Node2D

var definition: RigDefinition
var pose: RigPose
var palette_color: Color = Color("#FF6600")
var head_hollow: bool = true

var _stroke: Line2D
var _layer_back: Line2D
var _layer_front: Line2D
var _head: StickHead
var _sdf_layer: CanvasLayer
var _sdf_rect: ColorRect
var _sdf_material: ShaderMaterial
var _view_scale: float = 1.25
var _layered: bool = false
var _sdf: bool = false


func setup(p_definition: RigDefinition, palette: Dictionary, palette_name: String,
		dpi_scale: float) -> void:
	definition = p_definition
	_view_scale = definition.base_scale * dpi_scale
	scale = Vector2.ONE * _view_scale
	_layer_back = _make_stroke("StrokeBack", -2)
	_stroke = _make_stroke("Stroke", 0)
	_layer_front = _make_stroke("StrokeFront", 2)
	_head = StickHead.new()
	_head.name = "HeadCircle"
	_head.z_index = 20
	add_child(_head)
	_sdf_layer = CanvasLayer.new()
	_sdf_layer.name = "SdfLayer"
	add_child(_sdf_layer)
	_sdf_rect = ColorRect.new()
	_sdf_rect.name = "SdfStroke"
	_sdf_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sdf_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sdf_material = ShaderMaterial.new()
	_sdf_material.shader = load("res://scripts/render/sdf_stroke.gdshader")
	_sdf_rect.material = _sdf_material
	_sdf_rect.visible = false
	_sdf_layer.add_child(_sdf_rect)
	set_palette(palette, palette_name)


func _make_stroke(stroke_name: String, z: int) -> Line2D:
	var stroke := Line2D.new()
	stroke.name = stroke_name
	stroke.begin_cap_mode = Line2D.LINE_CAP_ROUND
	stroke.end_cap_mode = Line2D.LINE_CAP_ROUND
	stroke.joint_mode = Line2D.LINE_JOINT_ROUND
	stroke.antialiased = true
	stroke.round_precision = 8
	stroke.width = definition.line_width
	stroke.z_index = z
	add_child(stroke)
	return stroke


func set_layered(enabled: bool) -> void:
	_layered = enabled
	_layer_back.visible = enabled
	_layer_front.visible = enabled
	if pose != null:
		sync(pose)


func is_layered() -> bool:
	return _layered


func set_sdf(enabled: bool) -> void:
	_sdf = enabled
	if _sdf_rect != null:
		_sdf_rect.visible = enabled
	_stroke.visible = not enabled
	_layer_back.visible = not enabled and _layered
	_layer_front.visible = not enabled and _layered
	_head.visible = not enabled
	if pose != null:
		sync(pose)


func is_sdf() -> bool:
	return _sdf


func set_palette(palette: Dictionary, palette_name: String) -> void:
	var entries: Dictionary = palette.get("palettes", {})
	if not entries.has(palette_name):
		return
	var entry: Dictionary = entries[palette_name]
	palette_color = Color(str(entry.get("color", "#FF6600")))
	head_hollow = str(entry.get("head", "filled")) == "hollow"
	_stroke.default_color = palette_color
	_layer_back.default_color = palette_color
	_layer_front.default_color = palette_color
	_head.configure(_effective_head_radius(), palette_color, head_hollow,
			definition.head_line_width)
	if _sdf_material != null:
		_sdf_material.set_shader_parameter("stroke_color", palette_color)
		_sdf_material.set_shader_parameter("head_hollow", head_hollow)


func _effective_head_radius() -> float:
	return definition.head_radius * (1.0 if head_hollow else 0.75)


func _head_center_local(p: RigPose) -> Vector2:
	var neck := p.joint_pos[int(definition.joint_index[&"neck_top"])]
	var chest := p.joint_pos[int(definition.joint_index[&"chest"])]
	var dir := (neck - chest).normalized()
	if dir.length_squared() < 0.0001:
		dir = Vector2(0.0, -1.0)
	return neck + dir * _effective_head_radius()


func _has_l_feet() -> bool:
	return not head_hollow


func sync(p_pose: RigPose) -> void:
	if definition == null or p_pose == null:
		return
	pose = p_pose
	position = pose.root_pos
	if _sdf:
		_sync_sdf(pose)
		return
	if _layered:
		_layer_back.points = _build_back_path(pose)
		_stroke.points = _build_body_path(pose)
		_layer_front.points = _build_front_path(pose)
	else:
		_stroke.points = _build_path(pose)
	_head.position = _head_center_local(pose) - pose.root_pos


func _sync_sdf(p: RigPose) -> void:
	var view_size := get_viewport().get_visible_rect().size
	var segments := PackedVector4Array()
	for b in definition.bones:
		if b.id in [&"upper_arm_l", &"forearm_l", &"upper_arm_r", &"forearm_r",
				&"thigh_l", &"shin_l", &"thigh_r", &"shin_r"]:
			continue
		if (b.id == &"foot_l" or b.id == &"foot_r") and not _has_l_feet():
			continue
		var start := _joint_screen(p, b.start_idx)
		var end := _joint_screen(p, b.end_idx)
		if b.id == &"foot_l" or b.id == &"foot_r":
			end = start + (end - start) * 0.6
		segments.append(Vector4(start.x, start.y, end.x, end.y))
	_append_arm_curve(segments, p, &"upper_arm_l", &"forearm_l")
	_append_arm_curve(segments, p, &"upper_arm_r", &"forearm_r")
	_append_leg_curve(segments, p, &"thigh_l", &"shin_l")
	_append_leg_curve(segments, p, &"thigh_r", &"shin_r")
	var head_center := to_global(_head_center_local(p) - p.root_pos)
	_sdf_material.set_shader_parameter("screen_size", view_size)
	for i in segments.size():
		_sdf_material.set_shader_parameter("seg%d" % i, segments[i])
	for i in range(segments.size(), 21):
		_sdf_material.set_shader_parameter("seg%d" % i,
				Vector4(-1000.0, -1000.0, -1000.0, -1000.0))
	_sdf_material.set_shader_parameter("line_radius",
			definition.line_width * _view_scale * 0.5)
	_sdf_material.set_shader_parameter("head_center", head_center)
	_sdf_material.set_shader_parameter("head_radius",
			_effective_head_radius() * _view_scale)
	_sdf_material.set_shader_parameter("head_half_width",
			definition.head_line_width * _view_scale * 0.5)


func _joint_screen(p: RigPose, joint_index: int) -> Vector2:
	return to_global(p.joint_pos[joint_index] - p.root_pos)


func _bone_index(bone_id: StringName) -> int:
	for i in definition.bones.size():
		if definition.bones[i].id == bone_id:
			return i
	return -1


func _append_arm_curve(segments: PackedVector4Array, p: RigPose,
		upper_id: StringName, fore_id: StringName) -> void:
	var upper_index := _bone_index(upper_id)
	var fore_index := _bone_index(fore_id)
	if upper_index < 0 or fore_index < 0:
		return
	var shoulder := _joint_screen(p, definition.bones[upper_index].start_idx)
	var elbow := _joint_screen(p, definition.bones[upper_index].end_idx)
	var hand := _joint_screen(p, definition.bones[fore_index].end_idx)
	var prev := shoulder
	for step in 4:
		var t := float(step + 1) / 4.0
		var point := (shoulder * pow(1.0 - t, 2.0)
				+ elbow * 2.0 * (1.0 - t) * t + hand * t * t)
		segments.append(Vector4(prev.x, prev.y, point.x, point.y))
		prev = point


func _append_leg_curve(segments: PackedVector4Array, p: RigPose,
		thigh_id: StringName, shin_id: StringName) -> void:
	var thigh_index := _bone_index(thigh_id)
	var shin_index := _bone_index(shin_id)
	if thigh_index < 0 or shin_index < 0:
		return
	var hip := _joint_screen(p, definition.bones[thigh_index].start_idx)
	var knee := _joint_screen(p, definition.bones[thigh_index].end_idx)
	var ankle := _joint_screen(p, definition.bones[shin_index].end_idx)
	var prev := hip
	for step in 4:
		var t := float(step + 1) / 4.0
		var point := (hip * pow(1.0 - t, 2.0)
				+ knee * 2.0 * (1.0 - t) * t + ankle * t * t)
		segments.append(Vector4(prev.x, prev.y, point.x, point.y))
		prev = point


func _build_back_path(p: RigPose) -> PackedVector2Array:
	var points: Array[Vector2] = []
	_append(points, p, &"hand_l")
	_append(points, p, &"elbow_l")
	_append(points, p, &"chest")
	_append(points, p, &"pelvis")
	_append(points, p, &"knee_l")
	_append(points, p, &"ankle_l")
	if _has_l_feet():
		_append_short_toe(points, p, &"ankle_l", &"toe_l", false)
		_append(points, p, &"ankle_l")
	return PackedVector2Array(points)


func _build_body_path(p: RigPose) -> PackedVector2Array:
	var points: Array[Vector2] = []
	_append(points, p, &"chest")
	_append(points, p, &"neck_top")
	_append(points, p, &"chest")
	_append(points, p, &"pelvis")
	return PackedVector2Array(points)


func _build_front_path(p: RigPose) -> PackedVector2Array:
	var points: Array[Vector2] = []
	_append(points, p, &"pelvis")
	_append(points, p, &"knee_r")
	_append(points, p, &"ankle_r")
	if _has_l_feet():
		_append_short_toe(points, p, &"ankle_r", &"toe_r", false)
		_append(points, p, &"ankle_r")
	_append(points, p, &"knee_r")
	_append(points, p, &"pelvis")
	_append(points, p, &"chest")
	_append(points, p, &"elbow_r")
	_append(points, p, &"hand_r")
	return PackedVector2Array(points)


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
	if _has_l_feet():
		_append_short_toe(points, p, &"ankle_l", &"toe_l", false)
		_append(points, p, &"ankle_l")
	_append(points, p, &"knee_l")
	_append(points, p, &"pelvis")
	_append(points, p, &"knee_r")
	_append(points, p, &"ankle_r")
	if _has_l_feet():
		_append_short_toe(points, p, &"ankle_r", &"toe_r", false)
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


func _append_short_toe(points: Array[Vector2], p: RigPose,
		ankle_id: StringName, toe_id: StringName, mirror: bool,
		factor: float = 0.6) -> void:
	var ankle_index := int(definition.joint_index.get(ankle_id, -1))
	var toe_index := int(definition.joint_index.get(toe_id, -1))
	if ankle_index < 0 or toe_index < 0:
		return
	var ankle := p.joint_pos[ankle_index]
	var toe := p.joint_pos[toe_index]
	var short_toe := ankle + (toe - ankle) * factor
	if mirror:
		short_toe.x = ankle.x * 2.0 - short_toe.x
	points.append(short_toe - p.root_pos)


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
	if _layer_back != null:
		_layer_back.width = value
	if _layer_front != null:
		_layer_front.width = value
	if _head != null:
		_head.line_width = value
		_head.queue_redraw()
