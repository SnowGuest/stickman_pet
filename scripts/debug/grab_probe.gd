class_name GrabProbe
extends Node

var _shell: DesktopShell
var _definition: RigDefinition
var _pose: RigPose
var _renderer: StickRenderer


func setup(shell: DesktopShell, definition: RigDefinition, pose: RigPose,
		renderer: StickRenderer) -> void:
	_shell = shell
	_definition = definition
	_pose = pose
	_renderer = renderer
	_write_target()


func _write_result(screen: Vector2, local: Vector2) -> void:
	var nearest := -1
	var nearest_distance := INF
	for i in _pose.joint_pos.size():
		var point := _visual_joint(i)
		var distance := local.distance_to(point)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = i
	var joint_name := ""
	if nearest >= 0 and nearest < _definition.joints.size():
		joint_name = str(_definition.joints[nearest])
	_write_json("user://grab_result.json", {
		"screen": [screen.x, screen.y],
		"local": [local.x, local.y],
		"joint": joint_name,
		"distance": nearest_distance,
	})
	print("[grab] joint=", joint_name, " distance=", nearest_distance)


func _write_target() -> void:
	var index := int(_definition.joint_index.get(&"chest", -1))
	if index < 0:
		return
	var local := _visual_joint(index)
	var screen := _shell.local_to_global(local)
	var screen_logical := screen / _shell.dpi_scale
	_write_json("user://grab_target.json", {
		"screen": [screen.x, screen.y],
		"screen_logical": [screen_logical.x, screen_logical.y],
		"local": [local.x, local.y],
		"joint": "chest",
	})
	# 启动自检：目标局部点反算最近关节，拦截坐标系回归。
	_write_result(screen, local)


func refresh_target() -> void:
	_write_target()


func _visual_joint(index: int) -> Vector2:
	var root := _pose.root_pos
	return root + (_pose.joint_pos[index] - root) * _renderer.scale


func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))
		file.close()
