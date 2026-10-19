class_name RigDefinition
extends RefCounted

var bones: Array[BoneDef] = []
var joints: PackedStringArray = PackedStringArray()
var head_radius: float = 18.0
var base_scale: float = 1.25
var line_width: float = 6.0
var head_line_width: float = 6.0
var joint_index: Dictionary = {}
var topo_order: PackedInt32Array = PackedInt32Array()


func load_from_file(path: String) -> bool:
	var raw := FileAccess.get_file_as_string(path)
	if raw.is_empty():
		return false
	var data = JSON.parse_string(raw)
	if not (data is Dictionary):
		return false
	bones.clear()
	joints.clear()
	head_radius = float(data.get("head_radius", 18.0))
	base_scale = float(data.get("base_scale", 1.25))
	var render: Dictionary = data.get("render", {})
	line_width = float(render.get("line_width", 6.0))
	head_line_width = float(render.get("head_line_width", line_width))
	for joint in data.get("joints", []):
		joints.append(StringName(str(joint)))
	for item in data.get("bones", []):
		if not (item is Dictionary):
			return false
		var bone := BoneDef.new()
		bone.from_dict(item)
		bones.append(bone)
	return true


func compile() -> bool:
	joint_index.clear()
	for i in joints.size():
		joint_index[joints[i]] = i
	topo_order.clear()
	for i in bones.size():
		var bone := bones[i]
		bone.index = i
		if bone.length <= 0.01 or bone.mass <= 0.0 or bone.width <= 0.0:
			return false
		if not joint_index.has(bone.start_joint) or not joint_index.has(bone.end_joint):
			return false
		bone.start_idx = int(joint_index[bone.start_joint])
		bone.end_idx = int(joint_index[bone.end_joint])
		if bone.start_idx == bone.end_idx:
			return false
		bone.parent_index = -1
		var parent_abs := 0.0
		if bone.parent != &"":
			for j in range(i):
				if bones[j].id == bone.parent:
					bone.parent_index = j
					parent_abs = bones[j].rest_abs_deg
					break
			if bone.parent_index < 0:
				return false
		bone.rest_rel = deg_to_rad(wrapf(bone.rest_abs_deg - parent_abs, -180.0, 180.0))
		var sign := -1.0 if bone.mirror else 1.0
		bone.lo = deg_to_rad(minf(bone.limit_lo_deg, bone.limit_hi_deg)) * sign
		bone.hi = deg_to_rad(maxf(bone.limit_lo_deg, bone.limit_hi_deg)) * sign
		topo_order.append(i)
	return true


func create_rest_pose() -> RigPose:
	var pose := RigPose.new()
	pose.rel.resize(bones.size())
	for i in bones.size():
		pose.rel[i] = bones[i].rest_rel
	return pose


func joint_pos(pose: RigPose, joint: StringName) -> Vector2:
	if not joint_index.has(joint):
		return Vector2.ZERO
	return pose.joint_pos[int(joint_index[joint])]


func pose_bounds(pose: RigPose) -> Rect2:
	if pose.joint_pos.is_empty():
		return Rect2()
	var bounds := Rect2(pose.joint_pos[0], Vector2.ZERO)
	for point in pose.joint_pos:
		bounds = bounds.expand(point)
	var neck_index := int(joint_index.get(&"neck_top", -1))
	if neck_index >= 0:
		var center := pose.joint_pos[neck_index] + Vector2(0.0, -head_radius)
		var head_box := Rect2(center - Vector2.ONE * head_radius,
				Vector2.ONE * head_radius * 2.0)
		bounds = bounds.merge(head_box)
	return bounds.grow(line_width * 0.5)
