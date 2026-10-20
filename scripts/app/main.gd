extends Node2D

const PALETTE_ORDER := ["green", "orange", "blue", "red", "yellow"]
const FALL_GRAVITY := 2300.0

enum PostState { NONE, FALLING, LANDING, GETTING_UP }

var shell: DesktopShell
var single: SingleInstance
var definition: RigDefinition
var pose: RigPose
var renderer: StickRenderer
var passthrough: PassthroughService
var debug: DebugOverlay
var tray: TrayService
var global_mouse: GlobalMouse
var grab_probe: GrabProbe
var panel: FloatPanel
var anim_library: AnimLibrary
var anim_player: AnimPlayer
var physics: PhysicsController
var context_menu: PopupMenu

var palette_data: Dictionary = {}
var palette_index: int = 1
var _last_view_size: Vector2 = Vector2.ZERO
var _standing_root_y: float = 0.0
var _post_state: PostState = PostState.NONE
var _post_time: float = 0.0
var _fall_vy: float = 0.0


func _ready() -> void:
	var boot_start := Time.get_ticks_msec()
	var args := OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	var debug_mode := args.has("--pet-debug")
	var safe_mode := args.has("--safe")
	var no_passthrough := args.has("--no-passthrough")
	var screenshot_mode := args.has("--screenshot") or args.has("--pet-screenshot")
	var grab_probe_mode := args.has("--pet-grab-probe")
	var fall_demo_mode := args.has("--pet-fall-demo")
	var anim_override := &""
	var anim_time := 0.0
	for arg in args:
		if arg.begins_with("--anim="):
			anim_override = StringName(arg.trim_prefix("--anim="))
		elif arg.begins_with("--anim-time="):
			anim_time = float(arg.trim_prefix("--anim-time="))
	var dpi_override := 0.0
	for arg in args:
		if arg.begins_with("--dpi="):
			dpi_override = float(arg.trim_prefix("--dpi="))

	single = SingleInstance.new()
	if not single.acquire():
		push_error("已有实例在运行")
		get_tree().quit(1)
		return

	shell = DesktopShell.new()
	add_child(shell)
	shell.setup(debug_mode, safe_mode, dpi_override)

	if not _load_rig():
		get_tree().quit(1)
		return
	pose = definition.create_rest_pose()
	renderer = StickRenderer.new()
	add_child(renderer)
	renderer.setup(definition, palette_data, PALETTE_ORDER[palette_index],
			shell.dpi_scale)

	anim_library = AnimLibrary.new()
	if not anim_library.load_dir("res://assets/anims", definition):
		push_warning("动画库为空: %s" % str(anim_library.errors))
	anim_player = AnimPlayer.new()
	add_child(anim_player)
	anim_player.setup(definition, anim_library)
	anim_player.play(&"idle", 0.0)
	if anim_override != &"":
		anim_player.play(anim_override, 0.0)
	if anim_time > 0.0 and anim_player.current != null:
		anim_player.seek(anim_time / anim_player.current.length)

	physics = PhysicsController.new()
	add_child(physics)
	physics.setup(definition)
	anim_player.event_fired.connect(func(event_name: String) -> void:
		print("[anim] event=", event_name))

	_apply_layout()
	_last_view_size = get_viewport().get_visible_rect().size

	passthrough = PassthroughService.new()
	add_child(passthrough)
	passthrough.setup(not no_passthrough and not debug_mode)
	passthrough.tick(1.0 / 30.0, definition, pose, renderer.get_view_scale())

	debug = DebugOverlay.new()
	add_child(debug)
	debug.setup(definition, pose, renderer, passthrough)
	debug.visible = debug_mode
	debug.palette_cycle.connect(_on_palette_cycle)
	debug.animation_selected.connect(_on_animation_selected)
	anim_player.clip_changed.connect(_on_anim_clip_changed)
	_update_anim_highlight()

	panel = FloatPanel.new()
	add_child(panel)
	var anim_names := anim_library.names()
	var anim_index := maxi(0, anim_names.find(&"idle"))
	panel.setup(renderer.get_stroke_width(), PALETTE_ORDER, palette_index,
			anim_names, anim_index)
	panel.visible = debug_mode
	panel.line_width_changed.connect(_on_line_width_changed)
	panel.palette_selected.connect(_set_palette_by_name)
	panel.animation_selected.connect(_on_animation_selected)
	panel.animation_time_seek.connect(_on_animation_time_seek)
	panel.skeleton_toggled.connect(func(enabled: bool) -> void:
		debug.show_skeleton = enabled)

	context_menu = PopupMenu.new()
	add_child(context_menu)
	_build_context_menu()
	context_menu.id_pressed.connect(_on_context_menu_id)
	context_menu.popup_hide.connect(_on_context_menu_hidden)

	tray = TrayService.new()
	add_child(tray)
	if not screenshot_mode and tray.setup():
		tray.command_received.connect(_on_tray_command)

	global_mouse = GlobalMouse.new()
	add_child(global_mouse)
	global_mouse.setup(tray.get_mouse_path())
	if grab_probe_mode:
		grab_probe = GrabProbe.new()
		add_child(grab_probe)
		grab_probe.setup(shell, definition, pose, renderer, global_mouse)
	if fall_demo_mode:
		_trigger_fall_demo()

	if screenshot_mode:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var shot_path := ProjectSettings.globalize_path("user://p1_viewport.png")
		image.save_png(shot_path)
		print("[debug] screenshot=", shot_path)
		get_tree().quit()
		return

	print("[main] ready screen=%d dpi=%.2f screen_dpi=%d size=%s viewport=%s window=%s boot=%dms" % [
		shell.screen, shell.dpi_scale, DisplayServer.screen_get_dpi(shell.screen),
		str(shell.content_size),
		str(get_viewport().get_visible_rect().size), str(get_window().size),
		Time.get_ticks_msec() - boot_start])


func _load_rig() -> bool:
	var palette_raw := FileAccess.get_file_as_string(
			"res://assets/palettes/stickman_palette.json")
	var parsed = JSON.parse_string(palette_raw)
	if not (parsed is Dictionary):
		push_error("配色 JSON 解析失败")
		return false
	palette_data = parsed

	definition = RigDefinition.new()
	if not definition.load_from_file("res://assets/rigs/stickman.json"):
		push_error("骨骼 JSON 加载失败")
		return false
	if not definition.compile():
		push_error("骨骼编译失败")
		return false
	return true


func _place_pet() -> void:
	var scale := definition.base_scale * shell.dpi_scale
	var bottom_pad := maxf(8.0, definition.line_width * scale * 0.5 + 2.0)
	var floor_y := shell.content_size.y - bottom_pad
	pose.root_pos = Vector2(shell.content_size.x * 0.5,
			floor_y - 50.0 * scale)
	pose.root_angle = 0.0
	_apply_display_pose()
	RigState.resolve(definition, pose)
	_fit_pose_in_view(32.0, bottom_pad)
	RigState.resolve(definition, pose)


func _fit_pose_in_view(top_margin: float, bottom_margin: float) -> void:
	var view := Rect2(Vector2(top_margin, top_margin),
			Vector2(shell.content_size.x - top_margin * 2.0,
					shell.content_size.y - top_margin - bottom_margin))
	var render_scale := definition.base_scale * shell.dpi_scale
	var raw := definition.pose_bounds(pose)
	var bounds := Rect2(pose.root_pos + (raw.position - pose.root_pos) * render_scale,
			raw.size * render_scale)
	var shift := Vector2.ZERO
	if bounds.end.y > view.end.y:
		shift.y -= bounds.end.y - view.end.y
	elif bounds.position.y < view.position.y:
		shift.y += view.position.y - bounds.position.y
	if bounds.end.x > view.end.x:
		shift.x -= bounds.end.x - view.end.x
	elif bounds.position.x < view.position.x:
		shift.x += view.position.x - bounds.position.x
	pose.root_pos += shift


func _apply_display_pose() -> void:
	# 静止展示用轻微 A-pose；骨骼 JSON 的 rest 仍保持不变。
	_set_rel_raw(&"upper_arm_l", -150.0)
	_set_rel_raw(&"upper_arm_r", 150.0)
	_set_rel_raw(&"forearm_l", 0.0)
	_set_rel_raw(&"forearm_r", 0.0)
	_set_rel_raw(&"thigh_l", 100.0)
	_set_rel_raw(&"thigh_r", 80.0)
	_set_rel_raw(&"shin_l", -10.0)
	_set_rel_raw(&"shin_r", 10.0)
	_set_rel_raw(&"foot_l", 90.0)
	_set_rel_raw(&"foot_r", -90.0)


func _set_rel_raw(bone_id: StringName, rel_deg: float) -> void:
	for i in definition.bones.size():
		if definition.bones[i].id == bone_id:
			pose.rel[i] = deg_to_rad(rel_deg)
			return


func _process(dt: float) -> void:
	if shell == null:
		return
	var view_size := get_viewport().get_visible_rect().size
	if view_size != _last_view_size and view_size.x > 1.0 and view_size.y > 1.0:
		_last_view_size = view_size
		_apply_layout()
	shell.poll(dt)
	if physics != null and physics.active:
		physics.tick(dt, pose)
		renderer.sync(pose)
	elif _post_state != PostState.NONE:
		_tick_post_grab(dt)
	elif anim_player != null:
		anim_player.tick(dt, pose)
		RigState.resolve(definition, pose)
		renderer.sync(pose)
	if passthrough != null:
		passthrough.tick(dt, definition, pose, renderer.get_view_scale())


func _trigger_fall_demo() -> void:
	if physics != null:
		physics.stop()
	_cancel_post_grab()
	pose.root_pos.y = _standing_root_y - 480.0
	_post_state = PostState.FALLING
	_post_time = 0.0
	_fall_vy = 0.0
	anim_player.play(&"panic_fall", 0.0)
	print("[post] fall demo")


func _start_post_grab() -> void:
	if physics == null or physics.solver == null:
		return
	var pelvis := int(definition.joint_index[&"pelvis"])
	var root_y := physics.solver.pos[pelvis].y
	var release_vy := physics.get_release_velocity().y
	physics.stop()
	_post_time = 0.0
	_fall_vy = maxf(release_vy, 0.0)
	if root_y < _standing_root_y - 40.0:
		_post_state = PostState.FALLING
		anim_player.play(&"panic_fall", 0.12)
		print("[post] falling from ", root_y)
	else:
		_begin_landing()


func _begin_landing() -> void:
	_post_state = PostState.LANDING
	_post_time = 0.0
	pose.root_pos.y = _standing_root_y - 28.0
	anim_player.play(&"land", 0.05)
	print("[post] landing")


func _begin_get_up() -> void:
	_post_state = PostState.GETTING_UP
	_post_time = 0.0
	anim_player.play(&"get_up", 0.08)
	print("[post] get up")


func _finish_post_grab() -> void:
	_post_state = PostState.NONE
	_post_time = 0.0
	pose.root_pos.y = _standing_root_y
	anim_player.play(&"idle", 0.2)


func _cancel_post_grab() -> void:
	_post_state = PostState.NONE
	_post_time = 0.0


func _tick_post_grab(dt: float) -> void:
	if anim_player == null or anim_player.current == null:
		return
	_post_time += dt
	match _post_state:
		PostState.FALLING:
			_fall_vy += FALL_GRAVITY * dt
			pose.root_pos.y += _fall_vy * dt
			if pose.root_pos.y >= _standing_root_y - 28.0:
				_begin_landing()
		PostState.LANDING:
			if _post_time >= anim_player.current.length:
				_begin_get_up()
		PostState.GETTING_UP:
			var duration := maxf(anim_player.current.length, 0.001)
			var t := clampf(_post_time / duration, 0.0, 1.0)
			t = t * t * (3.0 - 2.0 * t)
			pose.root_pos.y = lerpf(_standing_root_y - 28.0,
					_standing_root_y, t)
			if t >= 1.0:
				_finish_post_grab()
	anim_player.tick(dt, pose)
	RigState.resolve(definition, pose)
	renderer.sync(pose)


func _apply_layout() -> void:
	if renderer == null or definition == null or pose == null:
		return
	var view_size := get_viewport().get_visible_rect().size
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		return
	shell.content_size = view_size
	_place_pet()
	if _post_state == PostState.NONE:
		_standing_root_y = pose.root_pos.y
	if physics != null and physics.active:
		physics.set_bounds(shell.local_floor_y(), 0.0, view_size.x)
		physics.solver.write_pose(pose)
	elif anim_player != null:
		anim_player.apply(pose)
	RigState.resolve(definition, pose)
	renderer.sync(pose)
	if grab_probe != null:
		grab_probe.refresh_target()
	if passthrough != null:
		passthrough.unlock()
		passthrough.tick(0.0, definition, pose, renderer.get_view_scale())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_apply_layout()


func _on_palette_cycle() -> void:
	var next := (palette_index + 1) % PALETTE_ORDER.size()
	_set_palette_by_name(PALETTE_ORDER[next])


func _on_animation_selected(clip_name: StringName) -> void:
	if physics != null:
		physics.stop()
	_cancel_post_grab()
	if anim_player != null:
		anim_player.play(clip_name, 0.2)
		anim_player.apply(pose)
		RigState.resolve(definition, pose)
		renderer.sync(pose)
		print("[anim] clip=", clip_name)
		if panel != null:
			panel.set_animation_selected(clip_name)
		_update_anim_highlight()


func _on_anim_clip_changed(_clip_name: StringName) -> void:
	_update_anim_highlight()


func _update_anim_highlight() -> void:
	if debug == null or anim_player == null or anim_player.current == null:
		return
	debug.highlight_bones = anim_player.current.tracks.duplicate()


func _on_animation_time_seek(normalized: float) -> void:
	if anim_player == null:
		return
	if physics != null:
		physics.stop()
	_cancel_post_grab()
	anim_player.seek(normalized)
	RigState.resolve(definition, pose)
	renderer.sync(pose)
	if passthrough != null:
		passthrough.unlock()


func _set_palette_by_name(palette_name: String) -> void:
	var index := PALETTE_ORDER.find(palette_name)
	if index < 0:
		return
	palette_index = index
	renderer.set_palette(palette_data, palette_name)
	print("[debug] palette=", palette_name)


func _on_line_width_changed(value: float) -> void:
	renderer.set_line_width(value)
	print("[debug] line_width=", value)


func _build_context_menu() -> void:
	context_menu.add_item("显示/隐藏", 1)
	context_menu.add_item("静音", 2)
	context_menu.add_separator()
	context_menu.add_item("待机", 10)
	context_menu.add_item("走路", 11)
	context_menu.add_item("被抓", 12)
	context_menu.add_item("挥手", 13)
	context_menu.add_item("摔倒", 14)
	context_menu.add_separator()
	context_menu.add_item("退出", 9)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and physics != null and physics.grabbing:
		var motion_local := shell.global_to_local(DisplayServer.mouse_get_position())
		physics.drag(motion_local)
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseButton):
		return
	var local := shell.global_to_local(DisplayServer.mouse_get_position())
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _is_over_pet(local):
			_cancel_post_grab()
			var view_size := get_viewport().get_visible_rect().size
			if not physics.active:
				var started := physics.start_with_pose(pose, local,
						shell.local_floor_y(), 0.0, view_size.x)
				if not started:
					physics.stop()
					return
			elif not physics.begin_drag(local, shell.local_floor_y(),
					0.0, view_size.x):
				return
			passthrough.lock_full(shell.content_size)
			get_viewport().set_input_as_handled()
			print("[physics] grab local=", local)
		elif not event.pressed and physics.grabbing:
			physics.end_drag()
			passthrough.unlock()
			_start_post_grab()
			get_viewport().set_input_as_handled()
			print("[physics] release")
		return
	if event.button_index != MOUSE_BUTTON_RIGHT or not event.pressed:
		return
	if not _is_over_pet(local):
		return
	get_viewport().set_input_as_handled()
	_open_context_menu(local)


func _open_context_menu(local: Vector2) -> void:
	passthrough.lock_full(shell.content_size)
	context_menu.popup(Rect2i(Vector2i(local), Vector2i(220, 0)))
	var marker := FileAccess.open("user://context_menu_open.txt", FileAccess.WRITE)
	if marker != null:
		marker.store_string(str(local))
		marker.close()
	print("[menu] open local=", local)


func _is_over_pet(local: Vector2) -> bool:
	var region := passthrough.build_region(definition, pose,
			renderer.get_view_scale())
	return region.size() >= 3 and Geometry2D.is_point_in_polygon(local, region)


func _on_context_menu_hidden() -> void:
	passthrough.unlock()


func _on_context_menu_id(id: int) -> void:
	match id:
		1:
			_on_tray_command("toggle")
		2:
			_on_tray_command("mute")
		10:
			_on_animation_selected(&"idle")
		11:
			_on_animation_selected(&"walk")
		12:
			_on_animation_selected(&"drag_idle")
		13:
			_on_animation_selected(&"wave")
		14:
			_trigger_fall_demo()
		9:
			get_tree().quit()


func _on_tray_command(command: String) -> void:
	match command:
		"quit":
			get_tree().quit()
		"show":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_move_to_foreground()
		"toggle":
			_toggle_visible()
		"mute":
			var bus := AudioServer.get_bus_index("Master")
			AudioServer.set_bus_mute(bus, not AudioServer.is_bus_mute(bus))
		"topmost":
			var flag := DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP
			DisplayServer.window_set_flag(flag,
					not DisplayServer.window_get_flag(flag))


func _toggle_visible() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_move_to_foreground()
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)


func _exit_tree() -> void:
	if shell != null:
		shell.restore()
	if tray != null:
		tray.shutdown()
	if single != null:
		single.release()
