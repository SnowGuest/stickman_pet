extends SceneTree

## P0 工程基线测试。
## 不依赖外部框架；由 tools/gate.ps1 -Full 以 --script 运行。

var _checks := 0
var _failures := 0


func _initialize() -> void:
	print("[tests] P0 engineering baseline")
	_test_project_settings()
	_test_main_scene()
	_test_theme()
	_test_icons()
	_test_audio()
	_test_rig()
	_test_fk()
	_test_animation()
	_test_brain()
	_test_physics()
	_test_passthrough()
	_test_renderer()
	_test_taskbar_geometry()
	_test_coordinates()
	_test_palette()
	_test_export_preset()
	print("[tests] checks=%d failures=%d" % [_checks, _failures])
	if _failures > 0:
		push_error("[tests] FAIL")
		quit(1)
	else:
		print("[tests] PASS")
		quit(0)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if ok:
		print("  PASS  " + label)
	else:
		_failures += 1
		push_error("  FAIL  " + label)


func _setting(key: String, fallback = null):
	return ProjectSettings.get_setting(key, fallback)


func _test_project_settings() -> void:
	_check(str(_setting("application/config/name", "")) == "Stickman Pet",
			"application/config/name")
	_check(str(_setting("application/run/main_scene", "")) == "res://scenes/main.tscn",
			"main scene path")
	_check(str(_setting("application/config/icon", "")) == "res://assets/icons/icon_512.png",
			"project icon path")
	_check(bool(_setting("display/window/size/transparent", false)), "transparent window")
	_check(bool(_setting("display/window/per_pixel_transparency/allowed", false)),
			"per-pixel transparency")
	_check(bool(_setting("display/window/dpi/allow_hidpi", false)), "HiDPI allowed")
	_check(int(_setting("rendering/anti_aliasing/quality/msaa_2d", 0)) >= 3,
			"2D MSAA 8x enabled")
	_check(bool(_setting("display/window/size/borderless", false)), "borderless")
	_check(bool(_setting("display/window/size/always_on_top", false)), "always on top")
	_check(not bool(_setting("display/window/size/resizable", true)), "not resizable")
	_check(str(_setting("display/window/stretch/mode", "disabled")) == "disabled",
			"stretch disabled")
	_check(int(_setting("display/window/size/viewport_width", 0)) == 1280,
			"viewport width 1280")
	_check(int(_setting("display/window/size/viewport_height", 0)) == 720,
			"viewport height 720")
	_check(str(_setting("gui/theme/custom", "")) == "res://assets/themes/pet_theme.tres",
			"global theme")
	_check(int(_setting("debug/gdscript/warnings/untyped_declaration", -1)) == 1,
			"warning: untyped declaration")
	_check(int(_setting("debug/gdscript/warnings/unsafe_property_access", -1)) == 1,
			"warning: unsafe property")
	_check(int(_setting("debug/gdscript/warnings/unsafe_method_access", -1)) == 1,
			"warning: unsafe method")
	_check(int(_setting("debug/gdscript/warnings/unsafe_cast", -1)) == 1,
			"warning: unsafe cast")
	_check(int(_setting("debug/gdscript/warnings/unsafe_call_argument", -1)) == 1,
			"warning: unsafe call argument")
	_check(int(_setting("debug/gdscript/warnings/return_value_discarded", -1)) == 1,
			"warning: discarded return value")


func _test_main_scene() -> void:
	var path := "res://scenes/main.tscn"
	_check(ResourceLoader.exists(path), "main scene exists")
	var scene = load(path)
	_check(scene is PackedScene, "main scene loads as PackedScene")
	if scene is PackedScene:
		var instance = scene.instantiate()
		_check(instance != null, "main scene instantiates")
		if instance != null:
			instance.free()


func _test_theme() -> void:
	var theme = load("res://assets/themes/pet_theme.tres")
	_check(theme is Theme, "theme loads")
	if theme is Theme:
		var font = theme.default_font
		_check(font is Font, "theme default font")
		if font is Font:
			_check(font.has_char("火".unicode_at(0)), "font has CJK glyph 火")
			_check(font.has_char("宠".unicode_at(0)), "font has CJK glyph 宠")


func _test_icons() -> void:
	var icon = load("res://assets/icons/icon_512.png")
	_check(icon is Texture2D, "icon_512 loads")
	if icon is Texture2D:
		_check(icon.get_width() == 512 and icon.get_height() == 512,
				"icon_512 is 512x512")
	_check(FileAccess.file_exists("res://assets/icons/icon.ico"), "icon.ico exists")
	_check(FileAccess.file_exists("res://assets/icons/tray.ico"), "tray.ico exists")


func _test_audio() -> void:
	var paths := [
		"res://assets/sfx/sfx_step_01.ogg",
		"res://assets/sfx/sfx_land_soft.ogg",
		"res://assets/sfx/sfx_wave_whoosh.ogg",
		"res://assets/sfx/sfx_sit.ogg",
		"res://assets/sfx/sfx_wave.ogg",
		"res://assets/sfx/sfx_clap.ogg",
		"res://assets/sfx/sfx_pop.ogg",
	]
	for path in paths:
		var stream = load(path)
		_check(stream is AudioStreamOggVorbis, "audio loads: " + path.get_file())
		if stream is AudioStreamOggVorbis:
			_check(stream.get_length() > 0.0, "audio length: " + path.get_file())

	var wave = load("res://assets/sfx/sfx_wave.ogg")
	_check(wave is AudioStreamOggVorbis and wave.loop, "wave loop enabled")
	var whoosh = load("res://assets/sfx/sfx_wave_whoosh.ogg")
	_check(whoosh is AudioStreamOggVorbis and not whoosh.loop, "whoosh not looped")


func _test_rig() -> void:
	var raw := FileAccess.get_file_as_string("res://assets/rigs/stickman.json")
	var data = JSON.parse_string(raw)
	_check(data is Dictionary, "rig json parses")
	if not (data is Dictionary):
		return
	var bones = data.get("bones", [])
	var joints = data.get("joints", [])
	_check(bones.size() == 13, "rig has 13 bones")
	_check(joints.size() == 14, "rig has 14 joints")
	_check(is_equal_approx(float(data.get("head_radius", 0.0)), 18.0),
			"rig head_radius is 18")
	var seen := {}
	var parent_order_ok := true
	for bone in bones:
		var parent := str(bone.get("parent", ""))
		if parent != "" and not seen.has(parent):
			parent_order_ok = false
		seen[str(bone.get("id", ""))] = true
	_check(parent_order_ok, "rig parent order")


func _test_fk() -> void:
	var definition := RigDefinition.new()
	_check(definition.load_from_file("res://assets/rigs/stickman.json"), "rig loads")
	_check(definition.compile(), "rig compiles")
	if definition.bones.is_empty():
		return
	var pose := definition.create_rest_pose()
	pose.root_pos = Vector2(100.0, 200.0)
	pose.root_angle = 0.0
	RigState.resolve(definition, pose)
	var chest := definition.joint_pos(pose, &"chest")
	var head_top := definition.joint_pos(pose, &"head_top")
	_check(chest.is_equal_approx(Vector2(100.0, 170.0)), "FK chest position")
	_check(head_top.is_equal_approx(Vector2(100.0, 152.0)), "FK head position")
	var pelvis := definition.joint_pos(pose, &"pelvis")
	var knee := definition.joint_pos(pose, &"knee_l")
	_check(is_equal_approx(pelvis.distance_to(knee), 26.0), "FK thigh length")
	var arm_index := -1
	for i in definition.bones.size():
		if definition.bones[i].id == &"upper_arm_l":
			arm_index = i
			break
	var arm_angle := pose.abs_angle[arm_index]
	_check(absf(wrapf(arm_angle - deg_to_rad(96.0), -PI, PI)) < 0.001,
			"FK upper arm angle")


func _test_animation() -> void:
	var definition := RigDefinition.new()
	definition.load_from_file("res://assets/rigs/stickman.json")
	definition.compile()
	var library := AnimLibrary.new()
	_check(library.load_dir("res://assets/anims", definition), "animation library loads")
	_check(library.errors.is_empty(), "animation clips validate")
	_check(library.clips.size() >= 3, "animation clips count")
	_check(library.get_clip(&"idle") != null, "idle clip")
	_check(library.get_clip(&"walk") != null, "walk clip")
	_check(library.get_clip(&"drag_idle") != null, "drag_idle clip")
	_check(library.get_clip(&"wave") != null, "wave performance clip")

	var all_finite := true
	for clip_name in library.names():
		var clip := library.get_clip(clip_name)
		var out := PackedFloat32Array()
		for i in 1000:
			PoseSampler.sample_rel(clip, definition, clip.length * i / 1000.0, out)
			for value in out:
				if is_nan(value) or is_inf(value):
					all_finite = false
	_check(all_finite, "1000 samples finite")

	var abs := PackedFloat32Array()
	abs.resize(definition.bones.size())
	for i in definition.bones.size():
		abs[i] = definition.bones[i].rest_abs_deg
	var rel := PackedFloat32Array()
	PoseSampler.to_relative(abs, definition, rel)
	_check(is_equal_approx(rel[0], definition.bones[0].rest_rel),
			"absolute to relative spine")
	var forearm_index := -1
	for i in definition.bones.size():
		if definition.bones[i].id == &"forearm_l":
			forearm_index = i
			break
	_check(forearm_index >= 0 and is_equal_approx(rel[forearm_index],
			definition.bones[forearm_index].rest_rel),
			"absolute to relative forearm")

	var a := PackedFloat32Array([0.0])
	var b := PackedFloat32Array([PI])
	var blended := PackedFloat32Array()
	PoseBlender.crossfade(a, b, 0.5, blended)
	_check(absf(absf(blended[0]) - PI * 0.5) < 0.001, "crossfade midpoint")
	var add_base := PackedFloat32Array([0.0])
	var add_value := PackedFloat32Array([0.1])
	var add_mask := PackedFloat32Array([1.0])
	PoseBlender.additive(add_base, add_value, add_mask, 0.5)
	_check(is_equal_approx(add_base[0], 0.05), "additive layer")

	var invalid := AnimClip.new()
	var error := invalid.load_from_dict({
		"name": "bad", "length": 1.0,
		"tracks": {"nope": [[0.0, 0.0], [1.0, 0.0]]},
	}, definition)
	_check(not error.is_empty(), "unknown bone rejected")

	var player := AnimPlayer.new()
	player.setup(definition, library)
	player.play(&"idle", 0.0)
	var pose := definition.create_rest_pose()
	for i in 40:
		player.tick(1.0 / 60.0, pose)
	player.play(&"walk", 0.2)
	var fade_step := 0.0
	var fade_prev: PackedVector2Array = PackedVector2Array()
	for i in 40:
		player.tick(1.0 / 60.0, pose)
		RigState.resolve(definition, pose)
		if i > 0:
			for j in pose.joint_pos.size():
				fade_step = maxf(fade_step, pose.joint_pos[j].distance_to(fade_prev[j]))
		fade_prev = pose.joint_pos.duplicate()
	_check(fade_step < 30.0, "crossfade has no visible jump")
	var player_finite := true
	for value in pose.rel:
		if is_nan(value) or is_inf(value):
			player_finite = false
	_check(player_finite, "crossfade produces finite pose")
	player.seek(0.5)
	_check(absf(player.time - player.current.length * 0.5) < 0.001,
			"animation seek")
	var events: Array[String] = []
	player.event_fired.connect(func(name: String) -> void: events.append(name))
	player.play(&"walk", 0.0)
	for i in 130:
		player.tick(1.0 / 60.0, pose)
	_check(events.has("step_l"), "walk emits step_l")
	_check(events.has("step_r"), "walk emits step_r")
	player.free()


func _test_brain() -> void:
	var definition := RigDefinition.new()
	definition.load_from_file("res://assets/rigs/stickman.json")
	definition.compile()
	var library := AnimLibrary.new()
	library.load_dir("res://assets/anims", definition)
	var player := AnimPlayer.new()
	player.setup(definition, library)
	var brain := PetBrain.new()
	brain.setup(player, 7)
	_check(brain.state == PetBrain.State.IDLE, "brain starts idle")
	_check(brain.activity_name == "breathe", "brain names idle activity")
	brain.force(PetBrain.State.WAVE)
	_check(brain.state == PetBrain.State.WAVE, "brain force state")
	_check(brain.activity_name == "greet", "brain names wave activity")
	for i in 180:
		brain.tick(1.0 / 60.0)
	_check(brain.state == PetBrain.State.WAVE, "forced brain holds state")
	brain.release_force()
	for i in 300:
		brain.tick(1.0 / 60.0)
	_check(brain.state != PetBrain.State.WAVE, "brain leaves wave")
	brain.force(PetBrain.State.LOOK)
	for i in 30:
		brain.tick(1.0 / 60.0)
	_check(absf(brain.look_angle) > 0.05, "look state adds head turn")
	brain.force(PetBrain.State.WALK)
	for i in 10:
		brain.tick(1.0 / 60.0)
	_check(brain.body_bob() <= 0.0, "walk adds body bob")
	_check(absf(brain.body_tilt()) > 0.0, "walk adds body tilt")
	brain.release_force()
	var seen := {}
	for i in 36000:
		brain.tick(1.0 / 60.0)
		seen[brain.state] = true
	_check(seen.size() >= 4, "brain visits all four activities over 10 minutes")
	brain.free()
	player.free()


func _test_physics() -> void:
	var definition := RigDefinition.new()
	definition.load_from_file("res://assets/rigs/stickman.json")
	definition.compile()
	var pose := definition.create_rest_pose()
	pose.root_pos = Vector2(500.0, 300.0)
	RigState.resolve(definition, pose)

	var solver := RagdollSolver.new()
	solver.build(definition)
	solver.start_from_pose(pose, 900.0, 0.0, 1000.0)
	solver.apply_velocity(0, 0.5, Vector2(2400.0, -2000.0), 1.0 / 120.0)
	for i in 600:
		solver.step(1.0 / 120.0)
	var max_error := 0.0
	for b in definition.bones:
		var dist := solver.pos[b.start_idx].distance_to(solver.pos[b.end_idx])
		max_error = maxf(max_error, absf(dist - b.length))
	_check(max_error < definition.bones[0].length * 0.02, "PBD bone length error")

	var grab_solver := RagdollSolver.new()
	grab_solver.build(definition)
	grab_solver.start_from_pose(pose, 900.0, 0.0, 1000.0)
	var bone := 0
	var t := 0.5
	var point := grab_solver.pos[definition.bones[bone].start_idx].lerp(
			grab_solver.pos[definition.bones[bone].end_idx], t)
	grab_solver.begin_grab(bone, t, point)
	grab_solver.grab_target = point + Vector2(120.0, 0.0)
	for i in 60:
		grab_solver.step(1.0 / 120.0)
	var current := grab_solver.pos[definition.bones[bone].start_idx].lerp(
			grab_solver.pos[definition.bones[bone].end_idx], t)
	_check(current.distance_to(grab_solver.grab_target) < 1.0,
			"PBD grab point")
	var finite := true
	for p in solver.pos:
		if not is_finite(p.x) or not is_finite(p.y):
			finite = false
	_check(finite, "PBD finite positions")

	var fall := RagdollSolver.new()
	fall.build(definition)
	var fall_pose := definition.create_rest_pose()
	fall_pose.root_pos = Vector2(500.0, 250.0)
	RigState.resolve(definition, fall_pose)
	fall.start_from_pose(fall_pose, 1200.0, 0.0, 1000.0)
	var fall_pelvis := int(definition.joint_index[&"pelvis"])
	for i in 20:
		fall.step(1.0 / 120.0)
	var speed_a := fall.pos[fall_pelvis].distance_to(
			fall.prev[fall_pelvis]) * 120.0
	for i in 20:
		fall.step(1.0 / 120.0)
	var speed_b := fall.pos[fall_pelvis].distance_to(
			fall.prev[fall_pelvis]) * 120.0
	_check(speed_b > speed_a * 1.8, "gravity keeps accelerating")
	var bounded := true
	for i in solver.pos.size():
		var r := solver.radius[i]
		if solver.pos[i].x < solver.wall_l + r - 0.01 \
				or solver.pos[i].x > solver.wall_r - r + 0.01 \
				or solver.pos[i].y < solver.ceiling_y + r - 0.01 \
				or solver.pos[i].y > solver.floor_y - r + 0.01:
			bounded = false
	_check(bounded, "PBD stays inside screen bounds")
	var max_violation := 0.0
	for i in definition.bones.size():
		var b := definition.bones[i]
		var cdir := solver.pos[b.end_idx] - solver.pos[b.start_idx]
		if cdir.length_squared() < 1e-8:
			continue
		var pdir := Vector2.from_angle(0.0)
		if b.parent_index >= 0:
			var pb := definition.bones[b.parent_index]
			pdir = solver.pos[pb.end_idx] - solver.pos[pb.start_idx]
		var rel := wrapf(cdir.angle() - pdir.angle(), -PI, PI)
		var lo := solver.limit_lo[i]
		var hi := solver.limit_hi[i]
		if hi - lo <= PI * 1.5:
			var violation := maxf(lo - rel, rel - hi)
			if violation > max_violation:
				max_violation = violation
	_check(max_violation < 0.05, "PBD joint limits hold")
	var drop := RagdollSolver.new()
	drop.build(definition)
	var drop_pose := definition.create_rest_pose()
	drop_pose.root_pos = Vector2(500.0, 300.0)
	RigState.resolve(definition, drop_pose)
	drop.start_from_pose(drop_pose, 900.0, 0.0, 1000.0)
	var pelvis := int(definition.joint_index[&"pelvis"])
	var low := INF
	var high := -INF
	for i in 600:
		drop.step(1.0 / 120.0)
		if i > 540:
			low = minf(low, drop.pos[pelvis].y)
			high = maxf(high, drop.pos[pelvis].y)
	_check(high - low < 2.0, "PBD settles without bounce")
	var max_speed := 0.0
	for i in drop.pos.size():
		max_speed = maxf(max_speed, drop.pos[i].distance_to(drop.prev[i]) * 120.0)
	_check(max_speed < 40.0, "PBD residual speed")

	var head_solver := RagdollSolver.new()
	head_solver.build(definition)
	head_solver.start_from_pose(pose, 900.0, 0.0, 1000.0)
	var neck := definition.joint_pos(pose, &"neck_top")
	var head_center := neck + Vector2(0.0, -definition.head_radius)
	var head_hit := head_solver.pick(head_center)
	_check(int(head_hit[0]) >= 0 and definition.bones[int(head_hit[0])].id in [&"head", &"neck"],
			"head circle is pickable")
	_check(head_hit.size() > 3 and (head_hit[3] as Vector2).length() < 0.01,
			"head pick uses neck anchor")

	var overlap_solver := RagdollSolver.new()
	overlap_solver.build(definition)
	overlap_solver.start_from_pose(pose, 900.0, 0.0, 1000.0)
	var chest_joint := int(definition.joint_index[&"chest"])
	var elbow_joint := int(definition.joint_index[&"elbow_l"])
	overlap_solver.pos[elbow_joint] = overlap_solver.pos[chest_joint]
	var overlap_hit := overlap_solver.pick(overlap_solver.pos[chest_joint])
	_check(int(overlap_hit[0]) >= 0 and definition.bones[int(overlap_hit[0])].id in
			[&"upper_arm_l", &"forearm_l"], "arm wins over torso when overlapping")

	var controller := PhysicsController.new()
	controller.setup(definition)
	var held_pose := definition.create_rest_pose()
	held_pose.root_pos = Vector2(500.0, 500.0)
	RigState.resolve(definition, held_pose)
	var chest := definition.joint_pos(held_pose, &"chest")
	var started := controller.start_with_pose(held_pose, chest, 900.0, 0.0, 1000.0)
	_check(started, "physics controller starts grab")
	var angle_start := (controller.solver.pos[int(definition.joint_index[&"chest"])]
			- controller.solver.pos[int(definition.joint_index[&"pelvis"])]).angle()
	for i in 180:
		controller.tick(1.0 / 60.0, held_pose)
	var angle_end := (controller.solver.pos[int(definition.joint_index[&"chest"])]
			- controller.solver.pos[int(definition.joint_index[&"pelvis"])]).angle()
	_check(absf(wrapf(angle_end - angle_start, -PI, PI)) < 0.30,
			"held grab does not self-rotate")
	var held_y := held_pose.root_pos.y
	controller.end_drag()
	for i in 60:
		controller.tick(1.0 / 60.0, held_pose)
	_check(held_pose.root_pos.y > held_y + 10.0, "release falls after long hold")
	_check(not controller.solver.sleeping or held_pose.root_pos.y > 800.0,
			"release does not sleep mid-air")
	for i in 120:
		controller.tick(1.0 / 60.0, held_pose)
	_check(controller.solver.is_supported(), "release reaches floor")

	var lift := PhysicsController.new()
	lift.setup(definition)
	var lift_pose := definition.create_rest_pose()
	lift_pose.root_pos = Vector2(500.0, 500.0)
	RigState.resolve(definition, lift_pose)
	var lift_chest := definition.joint_pos(lift_pose, &"chest")
	lift.start_with_pose(lift_pose, lift_chest, 900.0, 0.0, 1000.0)
	var lift_start := (lift.solver.pos[int(definition.joint_index[&"chest"])]
			- lift.solver.pos[int(definition.joint_index[&"pelvis"])]).angle()
	var lift_last := lift_start
	var lift_turn := 0.0
	for i in 90:
		lift.drag(lift_chest + Vector2(0.0, -220.0))
		lift.tick(1.0 / 60.0, lift_pose)
		var a := (lift.solver.pos[int(definition.joint_index[&"chest"])]
				- lift.solver.pos[int(definition.joint_index[&"pelvis"])]).angle()
		lift_turn += wrapf(a - lift_last, -PI, PI)
		lift_last = a
	_check(absf(lift_turn) < 0.6, "lift does not self-spin")
	lift.free()

	var slide := PhysicsController.new()
	slide.setup(definition)
	var slide_pose := definition.create_rest_pose()
	slide_pose.root_pos = Vector2(500.0, 500.0)
	RigState.resolve(definition, slide_pose)
	var slide_chest := definition.joint_pos(slide_pose, &"chest")
	slide.start_with_pose(slide_pose, slide_chest, 900.0, 0.0, 1000.0)
	var y_lo := INF
	var y_hi := -INF
	for i in 90:
		slide.drag(slide_chest + Vector2(100.0, 0.0))
		slide.tick(1.0 / 60.0, slide_pose)
		y_lo = minf(y_lo, slide_pose.root_pos.y)
		y_hi = maxf(y_hi, slide_pose.root_pos.y)
	for i in 180:
		slide.drag(slide_chest + Vector2(sin(i * 0.25) * 140.0, 0.0))
		slide.tick(1.0 / 60.0, slide_pose)
		y_lo = minf(y_lo, slide_pose.root_pos.y)
		y_hi = maxf(y_hi, slide_pose.root_pos.y)
	_check(y_hi - y_lo < 60.0, "horizontal drag remains physical")
	slide.free()

	for joint_name in [&"knee_l", &"elbow_l"]:
		var joint_ctrl := PhysicsController.new()
		joint_ctrl.setup(definition)
		var joint_pose := definition.create_rest_pose()
		joint_pose.root_pos = Vector2(500.0, 500.0)
		RigState.resolve(definition, joint_pose)
		var joint_point := definition.joint_pos(joint_pose, joint_name)
		joint_ctrl.start_with_pose(joint_pose, joint_point, 900.0, 0.0, 1000.0)
		for i in 120:
			joint_ctrl.drag(joint_point + Vector2(sin(i * 0.25) * 160.0, 0.0))
			joint_ctrl.tick(1.0 / 60.0, joint_pose)
		var joint_error := 0.0
		for b in definition.bones:
			var length := joint_ctrl.solver.pos[b.start_idx].distance_to(
					joint_ctrl.solver.pos[b.end_idx])
			joint_error = maxf(joint_error, absf(length - b.length))
		_check(joint_error < 1.0, "joint grab keeps bone length")
		joint_ctrl.free()

	var stop_ctrl := PhysicsController.new()
	stop_ctrl.setup(definition)
	var stop_pose := definition.create_rest_pose()
	stop_pose.root_pos = Vector2(500.0, 500.0)
	RigState.resolve(definition, stop_pose)
	var hand := definition.joint_pos(stop_pose, &"hand_l")
	stop_ctrl.start_with_pose(stop_pose, hand, 900.0, 0.0, 1000.0)
	for i in 60:
		stop_ctrl.drag(hand + Vector2(sin(i * 0.3) * 100.0, 0.0))
		stop_ctrl.tick(1.0 / 60.0, stop_pose)
	for i in 60:
		stop_ctrl.tick(1.0 / 60.0, stop_pose)
	var stop_speed := 0.0
	for i in stop_ctrl.solver.pos.size():
		stop_speed = maxf(stop_speed,
				stop_ctrl.solver.pos[i].distance_to(stop_ctrl.solver.prev[i]) * 120.0)
	_check(stop_speed < 30.0, "grab settles after mouse stops")
	stop_ctrl.free()

	var neck_ctrl := PhysicsController.new()
	neck_ctrl.setup(definition)
	var neck_pose := definition.create_rest_pose()
	neck_pose.root_pos = Vector2(500.0, 500.0)
	RigState.resolve(definition, neck_pose)
	var neck_point := definition.joint_pos(neck_pose, &"neck_top")
	neck_ctrl.start_with_pose(neck_pose, neck_point, 900.0, 0.0, 1000.0)
	var neck_fast := 0.0
	for i in 90:
		neck_ctrl.drag(neck_point + Vector2(sin(i * 0.2) * 30.0, 0.0))
		neck_ctrl.tick(1.0 / 60.0, neck_pose)
		for b in definition.bones:
			if b.id in [&"forearm_l", &"forearm_r", &"neck"]:
				neck_fast = maxf(neck_fast,
						neck_ctrl.solver.pos[b.end_idx].distance_to(
						neck_ctrl.solver.prev[b.end_idx]) * 120.0)
	_check(neck_fast < 100.0, "neck grab keeps arms from flailing")
	neck_ctrl.free()

	var head_ctrl := PhysicsController.new()
	head_ctrl.setup(definition)
	var head_pose := definition.create_rest_pose()
	head_pose.root_pos = Vector2(500.0, 500.0)
	RigState.resolve(definition, head_pose)
	var head_grab_point := definition.joint_pos(head_pose, &"neck_top") \
			+ Vector2(0.0, -definition.head_radius)
	head_ctrl.start_with_pose(head_pose, head_grab_point, 900.0, 0.0, 1000.0)
	for i in 60:
		head_ctrl.drag(head_grab_point + Vector2(sin(i * 0.3) * 80.0, 0.0))
		head_ctrl.tick(1.0 / 60.0, head_pose)
	var head_error := 0.0
	for b in definition.bones:
		var length := head_ctrl.solver.pos[b.start_idx].distance_to(
				head_ctrl.solver.pos[b.end_idx])
		head_error = maxf(head_error, absf(length - b.length))
	_check(head_error < 1.0, "head grab keeps bone length")
	head_ctrl.free()
	controller.free()


func _test_passthrough() -> void:
	var definition := RigDefinition.new()
	definition.load_from_file("res://assets/rigs/stickman.json")
	definition.compile()
	var pose := definition.create_rest_pose()
	pose.root_pos = Vector2(100.0, 200.0)
	RigState.resolve(definition, pose)
	var service := PassthroughService.new()
	var region := service.build_region(definition, pose)
	_check(region.size() >= 3, "passthrough hull generated")
	var chest := definition.joint_pos(pose, &"chest")
	_check(Geometry2D.is_point_in_polygon(chest, region), "passthrough contains chest")
	var scaled := service.build_region(definition, pose, 1.5)
	var neck := definition.joint_pos(pose, &"neck_top")
	var head_top := pose.root_pos + (neck - pose.root_pos) * 1.5 \
			+ Vector2(0.0, -(definition.head_radius + 2.0) * 1.5)
	_check(Geometry2D.is_point_in_polygon(head_top, scaled),
			"passthrough contains scaled head")
	service.free()


func _test_renderer() -> void:
	var definition := RigDefinition.new()
	definition.load_from_file("res://assets/rigs/stickman.json")
	definition.compile()
	var palette = JSON.parse_string(FileAccess.get_file_as_string(
			"res://assets/palettes/stickman_palette.json"))
	if not (palette is Dictionary):
		return
	var renderer := StickRenderer.new()
	renderer.setup(definition, palette, "orange", 1.0)
	var pose := definition.create_rest_pose()
	pose.root_pos = Vector2(100.0, 200.0)
	RigState.resolve(definition, pose)
	renderer.sync(pose)
	_check(renderer.get_node_or_null("Stroke") != null, "renderer single stroke")
	_check(renderer.get_stroke_point_count() == 17, "renderer one-stroke path")
	renderer.set_layered(true)
	renderer.sync(pose)
	_check(renderer.get_node("StrokeBack").points.size() > 0, "layered back stroke")
	_check(renderer.get_node("StrokeFront").points.size() > 0, "layered front stroke")
	renderer.set_layered(false)
	renderer.sync(pose)
	_check(renderer.get_stroke_point_count() == 17, "layered mode restores one-stroke path")
	_check(renderer.get_stroke_width() == 6.0, "renderer no outline width")
	_check(renderer.get_node("HeadCircle").z_index == 20, "renderer head z")
	_check(renderer.head_hollow, "renderer orange hollow head")
	_check(renderer.palette_color == Color("#FF6600"), "renderer palette color")
	for name in ["green", "blue", "red", "yellow"]:
		renderer.set_palette(palette, name)
		_check(not renderer.head_hollow, "renderer filled head " + name)
	renderer.set_palette(palette, "orange")
	_check(renderer.head_hollow, "renderer hollow head restored")
	renderer.free()


func _test_taskbar_geometry() -> void:
	_check(is_equal_approx(DesktopShell.floor_global_y(
			Rect2(0.0, 0.0, 1920.0, 1040.0)), 1038.0), "taskbar bottom floor")
	_check(is_equal_approx(DesktopShell.floor_global_y(
			Rect2(0.0, 40.0, 1920.0, 1040.0)), 1078.0), "taskbar top floor")
	_check(is_equal_approx(DesktopShell.floor_global_y(
			Rect2(60.0, 0.0, 1860.0, 1080.0)), 1078.0), "taskbar left floor")
	_check(is_equal_approx(DesktopShell.floor_global_y(
			Rect2(0.0, 0.0, 1860.0, 1080.0)), 1078.0), "taskbar right floor")


func _test_coordinates() -> void:
	var origin := Vector2(100.0, 50.0)
	var global := Vector2(354.0, 933.0)
	var local := DesktopShell.local_from_global(global, origin)
	_check(local.is_equal_approx(Vector2(254.0, 883.0)), "global to local")
	_check(DesktopShell.global_from_local(local, origin)
			.is_equal_approx(global), "local to global roundtrip")
	_check(DesktopShell.local_from_global(
			Vector2(-40.0, -20.0), Vector2(-100.0, -50.0)
			).is_equal_approx(Vector2(60.0, 30.0)), "negative multi-screen coords")
	_check(DesktopShell.local_from_global(Vector2(50.0, 60.0), Vector2.ZERO)
			.is_equal_approx(Vector2(50.0, 60.0)), "origin window coords")


func _test_palette() -> void:
	var raw := FileAccess.get_file_as_string("res://assets/palettes/stickman_palette.json")
	var data = JSON.parse_string(raw)
	_check(data is Dictionary, "palette json parses")
	if not (data is Dictionary):
		return
	_check(str(data.get("default", "")) == "orange", "palette default orange")
	var palettes = data.get("palettes", {})
	_check(palettes.size() == 5, "palette has 5 colors")
	var orange = palettes.get("orange", {})
	_check(str(orange.get("head", "")) == "hollow", "orange head is hollow")
	var expected := {
		"green": "#66CC00",
		"orange": "#FF6600",
		"blue": "#33CCFF",
		"red": "#CC0000",
		"yellow": "#FFCC00",
	}
	for name in expected:
		var entry: Dictionary = palettes.get(name, {})
		_check(Color(str(entry.get("color", ""))) == Color(str(expected[name])),
				"palette color " + name)
		var want_head := "hollow" if name == "orange" else "filled"
		_check(str(entry.get("head", "")) == want_head, "palette head " + name)


func _test_export_preset() -> void:
	var raw := FileAccess.get_file_as_string("res://export_presets.cfg")
	_check(raw.contains('name="Windows Desktop"'), "export preset name")
	_check(raw.contains('platform="Windows Desktop"'), "export preset platform")
	_check(raw.contains("binary_format/embed_pck=true"), "export embeds pck")
	_check(raw.contains('application/icon="res://assets/icons/icon.ico"'),
			"export uses icon.ico")
	_check(raw.contains('include_filter="scripts/tray/*.ps1,scripts/tray/*.exe"'),
			"export includes tray helper")
	_check(raw.contains("addons/godot_ai/*"), "export excludes godot_ai")
	_check(raw.contains("tests/*") and raw.contains("tools/*"), "export excludes dev dirs")
