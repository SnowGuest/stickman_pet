class_name GrabProbe
extends Node

var _shell: DesktopShell
var _definition: RigDefinition
var _pose: RigPose
var _renderer: StickRenderer
var _mouse: GlobalMouse
var _last_down: bool = false
var _last_screen: Vector2 = Vector2.INF


func setup(shell: DesktopShell, definition: RigDefinition, pose: RigPose,
		renderer: StickRenderer, mouse: GlobalMouse) -> void:
	_shell = shell
	_definition = definition
	_pose = pose
	_renderer = renderer
	_mouse = mouse
	_write_target()


func _process(_dt: float) -> void:
	if _mouse == null or not _mouse.has_state():
		return
	if _mouse.is_down and not _last_down:
		_probe(_mouse.pos)
	_last_down = _mouse.is_down


func _probe(screen: Vector2) -> void:
	var local := _shell.global_to_local(screen)
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
	# 启动自检：用目标屏幕点反算最近关节，拦截坐标系回归。
	_probe(screen)


func _visual_joint(index: int) -> Vector2:
	var root := _pose.root_pos
	return root + (_pose.joint_pos[index] - root) * _renderer.scale


func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))
		file.close()
