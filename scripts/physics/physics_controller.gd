class_name PhysicsController
extends Node

const H := 1.0 / 120.0

var definition: RigDefinition
var solver: RagdollSolver
var active: bool = false
var grabbing: bool = false

var _acc: float = 0.0
var _rest_steps: int = 0
var _grab_offset: Vector2 = Vector2.ZERO
var _last_target: Vector2 = Vector2.ZERO
var _velocity: Vector2 = Vector2.ZERO
var _last_delta: float = 1.0 / 60.0
var _render_prev: PackedVector2Array = PackedVector2Array()
var _grab_raw: Vector2 = Vector2.ZERO
var _grab_smooth: Vector2 = Vector2.ZERO
var _grab_relative: PackedVector2Array = PackedVector2Array()
var grab_smoothing: float = 14.0
var grab_stabilization: float = 0.0
var grab_still_delay: float = 0.08
var grab_still_damping: float = 0.10
var _since_drag: float = 1.0


func setup(p_definition: RigDefinition, view_scale: float = 1.0) -> void:
	definition = p_definition
	solver = RagdollSolver.new()
	solver.build(definition, view_scale)


func start(pose: RigPose, floor: float, left: float, right: float) -> void:
	solver.start_from_pose(pose, floor, left, right)
	solver.sleeping = false
	_acc = 0.0
	_rest_steps = 0
	active = true
	grabbing = false
	_render_prev = solver.pos.duplicate()


func begin_drag(local: Vector2, floor: float, left: float, right: float) -> bool:
	if not active:
		# caller supplies current pose via start_with_pose
		return false
	var hit := solver.pick(local)
	if int(hit[0]) < 0:
		return false
	var bone := int(hit[0])
	var t := float(hit[1])
	var local_offset: Vector2 = hit[3] if hit.size() > 3 else Vector2.ZERO
	var point := solver.pos[definition.bones[bone].start_idx].lerp(
			solver.pos[definition.bones[bone].end_idx], t) + local_offset
	solver.begin_grab(bone, t, point, local_offset)
	_apply_tone(bone)
	_grab_offset = local - point
	_last_target = local
	_grab_raw = local
	_grab_smooth = local
	_grab_relative.resize(solver.pos.size())
	for i in solver.pos.size():
		_grab_relative[i] = solver.pos[i] - point
	_velocity = Vector2.ZERO
	_last_delta = 1.0 / 60.0
	_since_drag = 1.0
	grabbing = true
	solver.floor_y = floor
	solver.wall_l = left
	solver.wall_r = right
	return true


func start_with_pose(pose: RigPose, local: Vector2, floor: float,
		left: float, right: float) -> bool:
	start(pose, floor, left, right)
	return begin_drag(local, floor, left, right)


func drag(local: Vector2) -> void:
	if not grabbing:
		return
	_velocity = (local - _last_target) / maxf(_last_delta, 0.001)
	_last_target = local
	_last_delta = 1.0 / 60.0
	_grab_raw = local + _grab_offset
	_since_drag = 0.0


func end_drag() -> void:
	if not grabbing:
		return
	_velocity = _velocity.limit_length(2400.0)
	solver.apply_velocity(solver.grab_bone, solver.grab_t, _velocity, H)
	solver.end_grab()
	grabbing = false
	# 松手后变成无肌肉张力的布娃娃，避免落地后还试图“站起来”。
	for i in definition.bones.size():
		solver.tone[i] = 0.0
		solver.world_bias[i] = 0.0


func get_release_velocity() -> Vector2:
	return _velocity


func stop() -> void:
	active = false
	grabbing = false
	if solver != null:
		solver.end_grab()


func set_bounds(floor: float, left: float, right: float) -> void:
	if solver == null:
		return
	solver.floor_y = floor
	solver.wall_l = left
	solver.wall_r = right


func tick(dt: float, pose: RigPose) -> void:
	if not active:
		return
	if _render_prev.size() != solver.pos.size():
		_render_prev = solver.pos.duplicate()
	if grabbing:
		_since_drag += dt
		if _since_drag > grab_still_delay:
			# 鼠标停住后快速收掉残余速度，避免关节惯性在抓点附近抽动。
			solver.grab_target = _grab_raw
			solver.damp_velocities(grab_still_damping)
		else:
			_grab_smooth = _grab_smooth.lerp(_grab_raw,
					1.0 - exp(-grab_smoothing * dt))
			solver.grab_target = _grab_smooth
	_acc += minf(dt, 1.0 / 30.0)
	var guard := 0
	while _acc >= H and guard < 4:
		_acc -= H
		solver.step(H)
		guard += 1
	if grabbing:
		_rest_steps = 0
	elif solver.is_supported() and solver.is_resting():
		_rest_steps += 1
		if _rest_steps >= 120:
			solver.sleeping = true
	else:
		_rest_steps = 0
	if grabbing and grab_stabilization > 0.0 and _grab_relative.size() == solver.pos.size():
		# 搬运稳定：向“抓点 + 初始相对位置”做少量刚性混合，
		# 保留重力和碰撞，但抑制左右平移诱发的上下摆动。
		for i in solver.pos.size():
			solver.pos[i] = solver.pos[i].lerp(_grab_smooth + _grab_relative[i],
					grab_stabilization)
	solver.write_pose_interpolated(pose, _render_prev, _acc / H)
	_render_prev = solver.pos.duplicate()


func _apply_tone(grab_bone: int) -> void:
	var profile := {
		&"spine": 0.42, &"neck": 0.30, &"head": 0.22,
		&"upper_arm_l": 0.04, &"upper_arm_r": 0.04,
		&"forearm_l": 0.02, &"forearm_r": 0.02,
		&"thigh_l": 0.05, &"thigh_r": 0.05,
		&"shin_l": 0.03, &"shin_r": 0.03,
		&"foot_l": 0.02, &"foot_r": 0.02,
	}
	var bone_id := definition.bones[grab_bone].id
	if bone_id == &"neck" or bone_id == &"head":
		profile = {
			&"spine": 0.10, &"neck": 0.06, &"head": 0.03,
			&"upper_arm_l": 0.02, &"upper_arm_r": 0.02,
			&"forearm_l": 0.01, &"forearm_r": 0.01,
			&"thigh_l": 0.02, &"thigh_r": 0.02,
			&"shin_l": 0.01, &"shin_r": 0.01,
			&"foot_l": 0.01, &"foot_r": 0.01,
		}
	elif bone_id in [&"forearm_l", &"forearm_r", &"upper_arm_l", &"upper_arm_r"]:
		profile = {
			&"spine": 0.35, &"neck": 0.25, &"head": 0.20,
			&"upper_arm_l": 0.08, &"upper_arm_r": 0.08,
			&"forearm_l": 0.05, &"forearm_r": 0.05,
			&"thigh_l": 0.06, &"thigh_r": 0.06,
			&"shin_l": 0.04, &"shin_r": 0.04,
			&"foot_l": 0.03, &"foot_r": 0.03,
		}
	elif bone_id in [&"thigh_l", &"thigh_r", &"shin_l", &"shin_r",
			&"foot_l", &"foot_r"]:
		profile = {
			&"spine": 0.30, &"neck": 0.20, &"head": 0.15,
			&"upper_arm_l": 0.03, &"upper_arm_r": 0.03,
			&"forearm_l": 0.02, &"forearm_r": 0.02,
			&"thigh_l": 0.10, &"thigh_r": 0.10,
			&"shin_l": 0.06, &"shin_r": 0.06,
			&"foot_l": 0.04, &"foot_r": 0.04,
		}
	for i in definition.bones.size():
		solver.tone[i] = 0.0
		solver.world_bias[i] = 0.0
	var spine_bone := -1
	for i in definition.bones.size():
		if definition.bones[i].id == &"spine":
			spine_bone = i
			break
	if spine_bone >= 0:
		# 抓取时不给躯干额外扶正，让头和四肢完整受重力。
		solver.world_bias[spine_bone] = 0.0
