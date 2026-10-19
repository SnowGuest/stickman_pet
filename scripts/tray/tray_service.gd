class_name TrayService
extends Node

signal command_received(command: String)

var _helper_pid: int = -1
var _poll_acc: float = 0.0
var _ready: bool = false
var _script_path: String = ""
var _exe_path: String = ""
var _command_path: String = ""
var _icon_path: String = ""
var _mouse_path: String = ""


func setup(icon_path: String = "res://assets/icons/tray.ico") -> bool:
	if DisplayServer.get_name() == "headless":
		return false

	# 临时目录通常不含空格，避免 OS.create_process 参数被空格拆开。
	var temp := OS.get_temp_dir()
	_command_path = temp.path_join("stickman_tray_cmd.txt")
	_mouse_path = temp.path_join("stickman_mouse.txt")
	_icon_path = temp.path_join("stickman_tray.ico")
	var icon_source := ProjectSettings.globalize_path(icon_path)
	if FileAccess.file_exists(icon_source):
		DirAccess.copy_absolute(icon_source, _icon_path)
	else:
		_icon_path = icon_source
	_clear_commands()

	var native_source := ProjectSettings.globalize_path("res://scripts/tray/tray_helper.exe")
	if FileAccess.file_exists(native_source):
		_exe_path = temp.path_join("stickman_tray.exe")
		DirAccess.copy_absolute(native_source, _exe_path)
		_helper_pid = OS.create_process(_exe_path, PackedStringArray([
			_icon_path, _command_path, str(OS.get_process_id()), _mouse_path,
		]))
		if _helper_pid > 0:
			_ready = true
			print("[tray] native pid=", _helper_pid)
			return true

	var source := FileAccess.get_file_as_string("res://scripts/tray/tray_helper.ps1")
	if source.is_empty():
		push_warning("托盘 helper 缺失")
		return false
	_script_path = temp.path_join("stickman_tray.ps1")
	var writer := FileAccess.open(_script_path, FileAccess.WRITE)
	if writer == null:
		push_warning("无法写入托盘 helper")
		return false
	writer.store_buffer(PackedByteArray([0xEF, 0xBB, 0xBF]))
	writer.store_string(source)
	writer.close()

	var args := PackedStringArray([
		"-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden",
		"-File", _script_path, "-IconPath", _icon_path,
		"-CommandFile", _command_path, "-ParentPid", str(OS.get_process_id()),
	])
	_helper_pid = OS.create_process("powershell.exe", args)
	_ready = _helper_pid > 0
	print("[tray] fallback pid=", _helper_pid)
	if not _ready:
		push_warning("托盘 helper 启动失败")
	return _ready


func _process(dt: float) -> void:
	if not _ready:
		return
	_poll_acc += dt
	if _poll_acc < 0.2:
		return
	_poll_acc = 0.0
	for command in _read_commands():
		command_received.emit(command)


func _read_commands() -> PackedStringArray:
	var result := PackedStringArray()
	if _command_path.is_empty() or not FileAccess.file_exists(_command_path):
		return result
	var file := FileAccess.open(_command_path, FileAccess.READ)
	if file == null:
		return result
	var raw := file.get_as_text()
	file.close()
	DirAccess.remove_absolute(_command_path)
	for line in raw.split("\n", false):
		var text := line.strip_edges()
		if not text.is_empty():
			result.append(text)
	return result


func _clear_commands() -> void:
	if not _command_path.is_empty() and FileAccess.file_exists(_command_path):
		DirAccess.remove_absolute(_command_path)


func shutdown() -> void:
	_ready = false
	if _helper_pid > 0:
		OS.kill(_helper_pid)
		_helper_pid = -1
	for path in [_script_path, _exe_path, _icon_path, _mouse_path]:
		if not path.is_empty() and FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	_clear_commands()


func _exit_tree() -> void:
	shutdown()


func get_mouse_path() -> String:
	return _mouse_path
