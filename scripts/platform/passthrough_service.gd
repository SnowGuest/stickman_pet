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


func tick(dt: float, definition: RigDefinition, pose: RigPose) -> void:
	if not enabled or definition == null or pose == null:
		return
	if _locked:
		return
	_acc += dt
	if _acc < 1.0 / HZ:
		return
	_acc = 0.0
	var region := build_region(definition, pose)
	if region.size() < 3:
		return
	var bounds := _bounds(region)
	if bounds.position.distance_to(_last_rect.position) < HYSTERESIS \
			and (bounds.size - _last_rect.size).length() < HYSTERESIS:
		return
	_last_rect = bounds
	_last_region = region
	DisplayServer.window_set_mouse_passthrough(region)


func build_region(definition: RigDefinition, pose: RigPose) -> PackedVector2Array:
	var points := PackedVector2Array()
	for bone in definition.bones:
		if bone.id == &"foot_l" or bone.id == &"foot_r":
			continue
		var a := pose.joint_pos[bone.start_idx]
		var b := pose.joint_pos[bone.end_idx]
		var radius := bone.width * 0.5 + 3.0
		for k in 6:
			var offset := Vector2.from_angle(TAU * k / 6.0) * radius
			points.append(a + offset)
			points.append(b + offset)
	var neck_index := int(definition.joint_index.get(&"neck_top", -1))
	if neck_index >= 0:
		var head := pose.joint_pos[neck_index] + Vector2(0.0, -definition.head_radius)
		for k in 12:
			points.append(head + Vector2.from_angle(TAU * k / 12.0)
					* (definition.head_radius + 3.0))
	if points.size() < 3:
		return PackedVector2Array()
	var hull := Geometry2D.convex_hull(points)
	if hull.size() < 3:
		return PackedVector2Array()
	if not Geometry2D.is_polygon_clockwise(hull):
		hull.reverse()
	var grown := Geometry2D.offset_polygon(hull, 3.0)
	return grown[0] if grown.size() > 0 else hull


func _bounds(region: PackedVector2Array) -> Rect2:
	var rect := Rect2(region[0], Vector2.ZERO)
	for point in region:
		rect = rect.expand(point)
	return rect


func get_last_region() -> PackedVector2Array:
	return _last_region
