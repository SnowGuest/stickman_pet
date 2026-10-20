extends Node2D

const PALETTE_ORDER := ["green", "orange", "blue", "red", "yellow"]

var shell: DesktopShell
var single: SingleInstance
var definition: RigDefinition
var pose: RigPose
var renderer: StickRenderer
var passthrough: PassthroughService
var debug: DebugOverlay
var tray: TrayService
var anim_library: AnimLibrary
var anim_player: AnimPlayer
var brain: PetBrain
var shadow: PetShadow
var audio: AudioService

var palette_data: Dictionary = {}
var palette_index: int = 1
var _last_view_size: Vector2 = Vector2.ZERO
var _base_root_y: float = 0.0
var context_layer: CanvasLayer
var context_root: Control
var context_panel: PanelContainer
var context_open: bool = false


func _ready() -> void:
	var boot_start := Time.get_ticks_msec()
	var args := OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	var debug_mode := args.has("--pet-debug")
	var safe_mode := args.has("--safe")
	var no_passthrough := args.has("--no-passthrough")
	var screenshot_mode := args.has("--screenshot") or args.has("--pet-screenshot")
	var context_menu_mode := args.has("--context-menu")
	var layered_mode := args.has("--layered")
	var sdf_mode := not args.has("--line") and not layered_mode
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
		elif arg.begins_with("--palette="):
			var requested := arg.trim_prefix("--palette=")
			var found := PALETTE_ORDER.find(requested)
			if found >= 0:
				palette_index = found

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
	renderer.set_layered(layered_mode)
	renderer.set_sdf(sdf_mode)
	shadow = PetShadow.new()
	add_child(shadow)
	shadow.setup(shell.local_floor_y(), renderer.get_view_scale())

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

	if anim_override == &"":
		brain = PetBrain.new()
		add_child(brain)
		brain.setup(anim_player)
		brain.state_changed.connect(_on_brain_state_changed)
		brain.footstep.connect(func() -> void:
			if audio != null:
				audio.play("sfx_step_01", -14.0))

	audio = AudioService.new()
	add_child(audio)
	audio.setup()

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
	_build_context_menu()
	if context_menu_mode:
		call_deferred("_open_context_menu", Vector2(220.0, 180.0))

	tray = TrayService.new()
	add_child(tray)
	if not screenshot_mode and tray.setup():
		tray.command_received.connect(_on_tray_command)

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
	if anim_player != null:
		if brain != null:
			brain.tick(dt)
		anim_player.tick(dt, pose)
		_apply_brain_look()
		if brain != null:
			pose.root_pos.y = _base_root_y + brain.body_bob()
		RigState.resolve(definition, pose)
		_apply_brain_tilt()
		renderer.sync(pose)
		if shadow != null:
			shadow.update_from_pose(pose, brain != null and brain.state == PetBrain.State.WALK)
	if passthrough != null:
		passthrough.tick(dt, definition, pose, renderer.get_view_scale())


func _apply_layout() -> void:
	if renderer == null or definition == null or pose == null:
		return
	var view_size := get_viewport().get_visible_rect().size
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		return
	shell.content_size = view_size
	_place_pet()
	_base_root_y = pose.root_pos.y
	if anim_player != null:
		anim_player.apply(pose)
	_apply_brain_look()
	RigState.resolve(definition, pose)
	_apply_brain_tilt()
	renderer.sync(pose)
	if shadow != null:
		shadow.floor_y = shell.local_floor_y()
		shadow.update_from_pose(pose, brain != null and brain.state == PetBrain.State.WALK)
	if passthrough != null and not context_open:
		passthrough.unlock()
		passthrough.tick(0.0, definition, pose, renderer.get_view_scale())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_apply_layout()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		_open_context_menu(event.position)
		get_viewport().set_input_as_handled()


func _build_context_menu() -> void:
	context_layer = CanvasLayer.new()
	context_layer.name = "ContextMenuLayer"
	context_layer.layer = 100
	add_child(context_layer)
	context_root = Control.new()
	context_root.name = "ContextMenu"
	context_root.mouse_filter = Control.MOUSE_FILTER_STOP
	context_root.visible = false
	context_layer.add_child(context_root)
	context_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.0, 0.0, 0.0, 0.001)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	context_root.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.gui_input.connect(_on_context_backdrop_input)

	context_panel = PanelContainer.new()
	context_panel.name = "Panel"
	context_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	context_root.add_child(context_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	context_panel.add_child(box)

	for action in [["自动行为", "auto"], ["Idle", "idle"], ["Walk", "walk"],
			["Wave", "wave"], ["Look", "look"]]:
		_add_context_button(box, action[0], action[1])
	box.add_child(HSeparator.new())
	for palette_name in PALETTE_ORDER:
		_add_context_button(box, palette_name, "palette_" + palette_name)
	box.add_child(HSeparator.new())
	_add_context_button(box, "调试面板", "debug")
	_add_context_button(box, "退出", "quit")


func _add_context_button(box: VBoxContainer, text: String, action: String) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(180.0, 28.0)
	button.pressed.connect(_on_context_action.bind(action))
	box.add_child(button)


func _on_context_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_context_menu()


func _on_context_action(action: String) -> void:
	_close_context_menu()
	match action:
		"auto":
			if brain != null:
				brain.release_force()
		"idle":
			if brain != null:
				brain.force(PetBrain.State.IDLE)
		"walk":
			if brain != null:
				brain.force(PetBrain.State.WALK)
		"wave":
			if brain != null:
				brain.force(PetBrain.State.WAVE)
		"look":
			if brain != null:
				brain.force(PetBrain.State.LOOK)
		"debug":
			if debug != null:
				debug.visible = not debug.visible
		"quit":
			get_tree().quit()
		_:
			if action.begins_with("palette_"):
				_set_palette_by_name(action.trim_prefix("palette_"))


func _open_context_menu(local_pos: Vector2) -> void:
	if context_open or context_root == null:
		return
	context_open = true
	context_root.visible = true
	if passthrough != null:
		passthrough.lock_full(get_viewport().get_visible_rect().size)
	context_panel.reset_size()
	var view_size := get_viewport().get_visible_rect().size
	var panel_size := context_panel.size
	context_panel.position = Vector2(
			clampf(local_pos.x, 8.0, maxf(8.0, view_size.x - panel_size.x - 8.0)),
			clampf(local_pos.y, 8.0, maxf(8.0, view_size.y - panel_size.y - 8.0)))


func _close_context_menu() -> void:
	if not context_open:
		return
	context_open = false
	context_root.visible = false
	if passthrough != null:
		passthrough.unlock()


func _on_palette_cycle() -> void:
	var next := (palette_index + 1) % PALETTE_ORDER.size()
	_set_palette_by_name(PALETTE_ORDER[next])


func _on_animation_selected(clip_name: StringName) -> void:
	if anim_player != null:
		anim_player.play(clip_name, 0.2)
		anim_player.apply(pose)
		RigState.resolve(definition, pose)
		renderer.sync(pose)
		print("[anim] clip=", clip_name)
		_update_anim_highlight()


func _on_anim_clip_changed(_clip_name: StringName) -> void:
	_update_anim_highlight()


func _update_anim_highlight() -> void:
	if debug == null or anim_player == null or anim_player.current == null:
		return
	debug.highlight_bones = anim_player.current.tracks.duplicate()


func _on_brain_state_changed(next_state: int, _clip: StringName) -> void:
	if audio == null:
		return
	if next_state == PetBrain.State.WAVE:
		audio.play("sfx_wave_whoosh", -12.0)


func _apply_brain_tilt() -> void:
	if brain == null:
		return
	var tilt := brain.body_tilt()
	if is_zero_approx(tilt):
		return
	var pivot := pose.root_pos
	for i in pose.joint_pos.size():
		pose.joint_pos[i] = pivot + (pose.joint_pos[i] - pivot).rotated(tilt)


func _apply_brain_look() -> void:
	if brain == null or is_zero_approx(brain.look_angle):
		return
	for i in definition.bones.size():
		var bone_id := definition.bones[i].id
		if bone_id == &"neck":
			pose.rel[i] += brain.look_angle * 0.35
		elif bone_id == &"head":
			pose.rel[i] += brain.look_angle


func _set_palette_by_name(palette_name: String) -> void:
	var index := PALETTE_ORDER.find(palette_name)
	if index < 0:
		return
	palette_index = index
	renderer.set_palette(palette_data, palette_name)
	print("[debug] palette=", palette_name)


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
