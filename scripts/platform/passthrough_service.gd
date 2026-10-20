class_name PassthroughService
extends Node

const HZ := 30.0
const HYSTERESIS := 0.75

var enabled: bool = true

var _acc: float = 0.0
var _last_rect: Rect2 = Rect2()
var _last_region: PackedVector2Array = PackedVector2Array()
var _locked: bool = false
var _window_size: Vector2 = Vector2.ZERO


func setup(p_enabled: bool) -> void:
	enabled = p_enabled


func lock_full(window_size: Vector2) -> void:
	_locked = true
	_window_size = window_size
	_submit_full()


func unlock() -> void:
	_locked = false
	_last_rect = Rect2()


func is_locked() -> bool:
	return _locked


func _submit_full() -> void:
	if _window_size.x <= 0.0 or _window_size.y <= 0.0:
		return
	var region := PackedVector2Array([
		Vector2.ZERO,
		Vector2(_window_size.x, 0.0),
		_window_size,
		Vector2(0.0, _window_size.y),
	])
	_last_region = region
	DisplayServer.window_set_mouse_passthrough(region)


func tick(dt: float, definition: RigDefinition, pose: RigPose,
		render_scale: float = 1.0) -> void:
	if not enabled or definition == null or pose == null:
		return
	if _locked:
		return
	_acc += dt
	if _acc < 1.0 / HZ:
		return
	_acc = 0.0
	var region := build_region(definition, pose, render_scale)
	if region.size() < 3:
		return
	var bounds := _bounds(region)
	if bounds.position.distance_to(_last_rect.position) < HYSTERESIS \
			and (bounds.size - _last_rect.size).length() < HYSTERESIS:
		return
	_last_rect = bounds
	_last_region = region
	DisplayServer.window_set_mouse_passthrough(region)


func build_region(definition: RigDefinition, pose: RigPose,
		render_scale: float = 1.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for bone in definition.bones:
		if bone.id == &"foot_l" or bone.id == &"foot_r":
			continue
		var a := _visual_joint(pose, bone.start_idx, render_scale)
		var b := _visual_joint(pose, bone.end_idx, render_scale)
		var radius := (bone.width * 0.5 + 3.0) * render_scale
		for k in 6:
			var offset := Vector2.from_angle(TAU * k / 6.0) * radius
			points.append(a + offset)
			points.append(b + offset)
	var neck_index := int(definition.joint_index.get(&"neck_top", -1))
	var chest_index := int(definition.joint_index.get(&"chest", -1))
	if neck_index >= 0:
		var neck := _visual_joint(pose, neck_index, render_scale)
		var dir := Vector2(0.0, -1.0)
		if chest_index >= 0:
			dir = (neck - _visual_joint(pose, chest_index,
					render_scale)).normalized()
			if dir.length_squared() < 0.0001:
				dir = Vector2(0.0, -1.0)
		var head := neck + dir * definition.head_radius * render_scale
		var head_radius := (definition.head_radius + 3.0) * render_scale
		for k in 16:
			points.append(head + Vector2.from_angle(TAU * k / 16.0)
					* head_radius)
	if points.size() < 3:
		return PackedVector2Array()
	var hull := Geometry2D.convex_hull(points)
	if hull.size() < 3:
		return PackedVector2Array()
	if not Geometry2D.is_polygon_clockwise(hull):
		hull.reverse()
	var grown := Geometry2D.offset_polygon(hull, 3.0 * render_scale)
	return grown[0] if grown.size() > 0 else hull


func _visual_joint(pose: RigPose, index: int, render_scale: float) -> Vector2:
	return pose.root_pos + (pose.joint_pos[index] - pose.root_pos) * render_scale


func _bounds(region: PackedVector2Array) -> Rect2:
	var rect := Rect2(region[0], Vector2.ZERO)
	for point in region:
		rect = rect.expand(point)
	return rect


func get_last_region() -> PackedVector2Array:
	return _last_region
