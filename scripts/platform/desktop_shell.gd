class_name DesktopShell
extends Node

var screen: int = 0
var usable_rect: Rect2 = Rect2()
var content_size: Vector2 = Vector2(1280.0, 720.0)
var dpi_scale: float = 1.0
var safe_mode: bool = false
var debug_focus: bool = false
var dpi_override: float = 0.0

var _probe_acc: float = 0.0
var _window: Window


func setup(p_debug_focus: bool = false, p_safe: bool = false,
		p_dpi_override: float = 0.0) -> void:
	debug_focus = p_debug_focus
	safe_mode = p_safe
	dpi_override = maxf(p_dpi_override, 0.0)
	_window = get_window()
	_window.transparent_bg = not safe_mode

	_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, not safe_mode)
	_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, not safe_mode)
	_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true)
	_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, not debug_focus and not safe_mode)

	Engine.max_fps = 60
	OS.low_processor_usage_mode = false
	_refresh(true)


func _set_flag(flag: int, enabled: bool) -> void:
	DisplayServer.window_set_flag(flag, enabled)


func _refresh(force: bool = false) -> void:
	var current := DisplayServer.window_get_current_screen()
	if current < 0:
		current = 0
	var rect := Rect2(DisplayServer.screen_get_usable_rect(current))
	var scale := DisplayServer.screen_get_scale(current)
	var dpi := DisplayServer.screen_get_dpi(current)
	# 部分 Windows 环境 screen_get_scale() 固定返回 1.0，但 DPI 已正确给到 144/192。
	if is_equal_approx(scale, 1.0) and dpi > 96:
		scale = snappedf(float(dpi) / 96.0, 0.01)
	if dpi_override > 0.0:
		scale = dpi_override
	var changed: bool = force or current != screen or rect != usable_rect or scale != dpi_scale
	if not changed:
		return
	screen = current
	usable_rect = rect
	dpi_scale = scale
	if safe_mode:
		content_size = Vector2(480.0, 320.0)
		DisplayServer.window_set_size(Vector2i(content_size))
		DisplayServer.window_set_position(Vector2i(
				rect.position + (rect.size - content_size) * 0.5))
	else:
		content_size = rect.size
		DisplayServer.window_set_position(Vector2i(rect.position))
		DisplayServer.window_set_size(Vector2i(rect.size))


func poll(dt: float) -> void:
	_probe_acc += dt
	if _probe_acc < 0.2:
		return
	_probe_acc = 0.0
	_refresh()


func global_to_local(global: Vector2) -> Vector2:
	return local_from_global(global, Vector2(DisplayServer.window_get_position()))


func local_to_global(local: Vector2) -> Vector2:
	return global_from_local(local, Vector2(DisplayServer.window_get_position()))


static func local_from_global(global: Vector2, window_pos: Vector2) -> Vector2:
	return global - window_pos


static func global_from_local(local: Vector2, window_pos: Vector2) -> Vector2:
	return local + window_pos


func local_floor_y() -> float:
	return content_size.y - 2.0


static func floor_global_y(usable: Rect2) -> float:
	return usable.position.y + usable.size.y - 2.0


func restore() -> void:
	if _window == null:
		return
	_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false)
	_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, false)
	_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, false)
	_window.transparent_bg = false
