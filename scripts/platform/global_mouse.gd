class_name GlobalMouse
extends Node

var pos: Vector2 = Vector2.ZERO
var is_down: bool = false

var _path: String = ""
var _acc: float = 0.0
var _has_state: bool = false


func setup(path: String) -> void:
	_path = path


func _process(dt: float) -> void:
	_acc += dt
	if _acc < 0.03:
		return
	_acc = 0.0
	poll()


func poll() -> void:
	if _path.is_empty() or not FileAccess.file_exists(_path):
		return
	var raw := FileAccess.get_file_as_string(_path).strip_edges()
	var parsed := parse_state(raw)
	if parsed.is_empty():
		return
	pos = parsed["pos"]
	is_down = parsed["down"]
	_has_state = true


func has_state() -> bool:
	return _has_state


static func parse_state(raw: String) -> Dictionary:
	var parts := raw.split(",")
	if parts.size() < 3:
		return {}
	return {
		"pos": Vector2(float(parts[0]), float(parts[1])),
		"down": parts[2].strip_edges() == "1",
	}
