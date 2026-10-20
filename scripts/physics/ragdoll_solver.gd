class_name RagdollSolver
extends RefCounted

var def: RigDefinition

var pos: PackedVector2Array = PackedVector2Array()
var prev: PackedVector2Array = PackedVector2Array()
var inv_mass: PackedFloat32Array = PackedFloat32Array()
var radius: PackedFloat32Array = PackedFloat32Array()
var drive_rel: PackedFloat32Array = PackedFloat32Array()
var tone: PackedFloat32Array = PackedFloat32Array()
var world_bias: PackedFloat32Array = PackedFloat32Array()
var bias_abs: PackedFloat32Array = PackedFloat32Array()
var limit_lo: PackedFloat32Array = PackedFloat32Array()
var limit_hi: PackedFloat32Array = PackedFloat32Array()
var subtree: Array[PackedInt32Array] = []

var grab_bone: int = -1
var grab_t: float = 0.5
var grab_local_offset: Vector2 = Vector2.ZERO
var grab_target: Vector2 = Vector2.ZERO
var grab_strength: float = 0.38
var grab_angular_damping: float = 0.35
var grab_vertical_damping: float = 1.0

var gravity: float = 2300.0
var damping: float = 1.0
var grab_damping: float = 0.985
var max_speed: float = 6000.0
var iterations: int = 8
var max_corr: float = 0.12
var floor_y: float = 1000.0
var ceiling_y: float = 0.0
var wall_l: float = 2.0
var wall_r: float = 1918.0
var restitution: float = 0.0
var friction: float = 0.72
var contact_damping: float = 0.35
var supported_damping: float = 0.15
var root_angle: float = 0.0
var view_scale: float = 1.0
var sleeping: bool = false
var _rest_steps: int = 0


func build(definition: RigDefinition, p_view_scale: float = 1.0) -> void:
	def = definition
	view_scale = p_view_scale
	var n := def.joints.size()
	pos.resize(n)
	prev.resize(n)
	inv_mass.resize(n)
	radius.resize(n)
	drive_rel.resize(def.bones.size())
	tone.resize(def.bones.size())
	world_bias.resize(def.bones.size())
	bias_abs.resize(def.bones.size())
	limit_lo.resize(def.bones.size())
	limit_hi.resize(def.bones.size())
	for i in n:
		inv_mass[i] = 0.0
		radius[i] = 2.0
	for b in def.bones:
		var inv := 1.0 / maxf(b.mass, 0.05)
		inv_mass[b.start_idx] += inv
		inv_mass[b.end_idx] += inv
	for i in n:
		inv_mass[i] = 1.0 / inv_mass[i] if inv_mass[i] > 0.0 else 0.0
	var head_len := 10.0
	for b in def.bones:
		if b.id == &"head":
			head_len = b.length
			break
	radius[int(def.joint_index[&"head_top"])] = maxf(def.head_radius * 2.0
			- head_len, def.head_radius) + def.head_line_width * 0.5
	for b in def.bones:
		var r := maxf(b.width * 0.5, 1.5)
		radius[b.start_idx] = maxf(radius[b.start_idx], r)
		radius[b.end_idx] = maxf(radius[b.end_idx], r)
	subtree.resize(def.bones.size())
	for i in def.bones.size():
		subtree[i] = _collect_subtree(i)
	for i in def.bones.size():
		drive_rel[i] = def.bones[i].rest_rel
		tone[i] = 0.0
		var min_limit := minf(def.bones[i].limit_lo_deg, def.bones[i].limit_hi_deg)
		var max_limit := maxf(def.bones[i].limit_lo_deg, def.bones[i].limit_hi_deg)
		limit_lo[i] = def.bones[i].rest_rel + deg_to_rad(min_limit)
		limit_hi[i] = def.bones[i].rest_rel + deg_to_rad(max_limit)
		# 人体活动范围覆盖（相对静止角）。左右镜像符号相反。
		match def.bones[i].id:
			&"forearm_l":
				limit_lo[i] = def.bones[i].rest_rel - deg_to_rad(20.0)
				limit_hi[i] = def.bones[i].rest_rel + deg_to_rad(150.0)
			&"forearm_r":
				limit_lo[i] = def.bones[i].rest_rel - deg_to_rad(150.0)
				limit_hi[i] = def.bones[i].rest_rel + deg_to_rad(20.0)
			&"shin_l":
				limit_lo[i] = def.bones[i].rest_rel - deg_to_rad(90.0)
				limit_hi[i] = def.bones[i].rest_rel + deg_to_rad(10.0)
			&"shin_r":
				limit_lo[i] = def.bones[i].rest_rel - deg_to_rad(10.0)
				limit_hi[i] = def.bones[i].rest_rel + deg_to_rad(90.0)
			&"spine":
				limit_lo[i] = def.bones[i].rest_rel - deg_to_rad(15.0)
				limit_hi[i] = def.bones[i].rest_rel + deg_to_rad(15.0)
			&"neck":
				limit_lo[i] = def.bones[i].rest_rel - deg_to_rad(10.0)
				limit_hi[i] = def.bones[i].rest_rel + deg_to_rad(10.0)
			&"head":
				limit_lo[i] = def.bones[i].rest_rel - deg_to_rad(10.0)
				limit_hi[i] = def.bones[i].rest_rel + deg_to_rad(10.0)
			&"foot_l", &"foot_r":
				# 脚骨不参与渲染，放开限位，避免脚部约束反向拉扯小腿。
				limit_lo[i] = -PI
				limit_hi[i] = PI


func sync_from_pose(pose: RigPose) -> void:
	pos = pose.joint_pos.duplicate()
	prev = pos.duplicate()
	sleeping = false
	_rest_steps = 0


func write_pose(pose: RigPose) -> void:
	var pelvis := int(def.joint_index[&"pelvis"])
	pose.root_pos = pos[pelvis]
	pose.joint_pos = pos.duplicate()


func write_pose_interpolated(pose: RigPose, from: PackedVector2Array,
		alpha: float) -> void:
	var pelvis := int(def.joint_index[&"pelvis"])
	if from.size() != pos.size():
		write_pose(pose)
		return
	pose.joint_pos.resize(pos.size())
	var t := clampf(alpha, 0.0, 1.0)
	for i in pos.size():
		pose.joint_pos[i] = from[i].lerp(pos[i], t)
	pose.root_pos = pose.joint_pos[pelvis]


func start_from_pose(pose: RigPose, floor: float, left: float, right: float) -> void:
	floor_y = floor
	wall_l = left
	wall_r = right
	damping = 1.0
	sync_from_pose(pose)
	for i in def.bones.size():
		drive_rel[i] = pose.rel[i]
		tone[i] = 0.0
		world_bias[i] = 0.0
		bias_abs[i] = 0.0


func step(h: float) -> void:
	if sleeping or def == null or pos.is_empty():
		return
	_integrate(h)
	for _i in iterations:
		_solve_angles()
		_solve_distances()
		_solve_grab()
		_solve_collisions()
	# 抓取/距离交替收尾：只做抓取会把关节钉住但拉长骨头，
	# 只做距离又会让抓点漂移；交替几次同时收敛。
	for _i in 8:
		_solve_grab()
		_solve_distances()
	if grab_bone >= 0:
		var head_idx := -1
		var neck_idx := -1
		for i in def.bones.size():
			if def.bones[i].id == &"head":
				head_idx = i
			elif def.bones[i].id == &"neck":
				neck_idx = i
		if def.bones[grab_bone].id == &"head" or def.bones[grab_bone].id == &"neck":
			# 头/颈很短，单独再投影几轮，避免抓头把颈骨拉长。
			for _i in 6:
				if neck_idx >= 0:
					_solve_bone_length(neck_idx)
				if head_idx >= 0:
					_solve_bone_length(head_idx)
			_solve_grab()
	# 最后的距离/抓取可能再次把骨骼推过限位；下一子步会继续修正，
	# 这里不再额外旋转，避免抓取时与鼠标目标形成来回拉扯。
	# 所有约束结束后再做一次硬边界夹取，任何约束都不能把角色推出屏幕。
	_solve_collisions()
	_clamp_bounds()
	if grab_bone >= 0:
		# 抓住时只耗散绕抓点的切向速度，抑制无质量自旋，保留整体摆动。
		for p in pos.size():
			var radius_vec := pos[p] - grab_target
			if radius_vec.length_squared() < 1.0:
				continue
			var tangent := Vector2(-radius_vec.y, radius_vec.x).normalized()
			var velocity := pos[p] - prev[p]
			prev[p] += tangent * velocity.dot(tangent) * grab_angular_damping
		for p in pos.size():
			var velocity := pos[p] - prev[p]
			velocity.y *= grab_vertical_damping
			prev[p] = pos[p] - velocity
	# 约束求解会注入额外速度；松手状态下每步再耗散一部分，避免“果冻/皮球”感。
	if grab_bone < 0:
		var supported := is_supported()
		var keep := supported_damping if supported else 1.0
		for p in pos.size():
			var velocity := (pos[p] - prev[p]) * keep
			prev[p] = pos[p] - velocity
		if supported and is_resting():
			_rest_steps += 1
			if _rest_steps >= 60:
				sleeping = true
		else:
			_rest_steps = 0
	for _i in pos.size():
		if not is_finite(pos[_i].x) or not is_finite(pos[_i].y):
			sync_from_pose_from_pos()
			return


func _integrate(h: float) -> void:
	var g := Vector2(0.0, gravity) * h * h
	for p in pos.size():
		if inv_mass[p] <= 0.0:
			prev[p] = pos[p]
			continue
		var velocity := (pos[p] - prev[p]) * damping
		velocity = velocity.limit_length(max_speed * h)
		prev[p] = pos[p]
		pos[p] += velocity + g


func _solve_distances() -> void:
	for b in def.bones:
		var a := b.start_idx
		var c := b.end_idx
		var delta := pos[c] - pos[a]
		var dist := delta.length()
		if dist < 0.0001:
			continue
		var wa := 0.0 if _is_grab_pinned(a) else inv_mass[a]
		var wc := 0.0 if _is_grab_pinned(c) else inv_mass[c]
		var wsum := wa + wc
		if wsum <= 0.0:
			continue
		var corr := delta * ((dist - b.length) / dist)
		pos[a] += corr * (wa / wsum)
		pos[c] -= corr * (wc / wsum)


func _is_grab_pinned(index: int) -> bool:
	if grab_bone < 0:
		return false
	var b := def.bones[grab_bone]
	if grab_t <= 0.02:
		return index == b.start_idx
	if grab_t >= 0.98:
		return index == b.end_idx
	return false


func _solve_angles() -> void:
	for i in def.topo_order:
		var b := def.bones[i]
		if b.parent_index < 0 and b.id == &"spine" and world_bias[i] > 0.0:
			_solve_world_bias(i, b)
		var cdir := pos[b.end_idx] - pos[b.start_idx]
		if cdir.length_squared() < 1e-8:
			continue
		var pdir: Vector2
		if b.parent_index >= 0:
			var pb := def.bones[b.parent_index]
			pdir = pos[pb.end_idx] - pos[pb.start_idx]
		else:
			pdir = Vector2.from_angle(root_angle)
		if pdir.length_squared() < 1e-8:
			continue
		var rel := wrapf(cdir.angle() - pdir.angle(), -PI, PI)
		var lo := limit_lo[i]
		var hi := limit_hi[i]
		var has_limit := hi - lo <= PI * 1.5
		var target := clampf(drive_rel[i] if i < drive_rel.size() else b.rest_rel,
				lo, hi)
		var err := 0.0
		var k := 0.0
		if has_limit and rel < lo:
			err = lo - rel
			k = 1.0
		elif has_limit and rel > hi:
			err = hi - rel
			k = 1.0
		else:
			err = wrapf(target - rel, -PI, PI)
			k = tone[i] if i < tone.size() else 0.0
			if absf(err) < 0.004:
				continue
		var k_iter := 1.0 - pow(1.0 - clampf(k, 0.0, 0.999),
				1.0 / float(iterations))
		_rotate_subtree(i, clampf(err * k_iter, -max_corr, max_corr))


func _solve_world_bias(index: int, bone: BoneDef) -> void:
	var cdir := pos[bone.end_idx] - pos[bone.start_idx]
	if cdir.length_squared() < 1e-8:
		return
	var err := wrapf(bias_abs[index] - cdir.angle(), -PI, PI)
	if absf(err) < 0.004:
		return
	var k_iter := 1.0 - pow(1.0 - clampf(world_bias[index], 0.0, 0.999),
			1.0 / float(iterations))
	_rotate_subtree(index, clampf(err * k_iter, -max_corr, max_corr))


func _solve_bone_length(index: int) -> void:
	var b := def.bones[index]
	var a := b.start_idx
	var c := b.end_idx
	var delta := pos[c] - pos[a]
	var dist := delta.length()
	if dist < 0.0001:
		return
	var wa := 0.0 if _is_grab_pinned(a) else inv_mass[a]
	var wc := 0.0 if _is_grab_pinned(c) else inv_mass[c]
	var wsum := wa + wc
	if wsum <= 0.0:
		return
	var corr := delta * ((dist - b.length) / dist)
	pos[a] += corr * (wa / wsum)
	pos[c] -= corr * (wc / wsum)


func _solve_grab() -> void:
	if grab_bone < 0:
		return
	var b := def.bones[grab_bone]
	var a := b.start_idx
	var c := b.end_idx
	var t := clampf(grab_t, 0.0, 1.0)
	var cur := pos[a].lerp(pos[c], t) + grab_local_offset
	var target := grab_target
	target.x = clampf(target.x, wall_l, wall_r)
	target.y = clampf(target.y, ceiling_y, floor_y)
	var delta := (target - cur) * grab_strength
	# 点在关节上时只钉住这个粒子，避免只移动单侧端点把骨头拉长。
	if t <= 0.02:
		pos[a] += delta
		return
	if t >= 0.98:
		pos[c] += delta
		return
	var wa := inv_mass[a]
	var wc := inv_mass[c]
	var denom := (1.0 - t) * (1.0 - t) * wa + t * t * wc
	if denom <= 1e-5:
		return
	# 按两端逆质量分配修正：重的一端动得少，抓取有惯性感。
	pos[a] += delta * (1.0 - t) * wa / denom
	pos[c] += delta * t * wc / denom


func _solve_collisions() -> void:
	for p in pos.size():
		var r := radius[p]
		if pos[p].y > floor_y - r:
			pos[p].y = floor_y - r
			# 地面不反弹；只保留很小的接触阻尼，避免“皮球感”。
			prev[p].y = pos[p].y
			var vx := pos[p].x - prev[p].x
			prev[p].x = pos[p].x - vx * (1.0 - friction) * contact_damping
		if pos[p].y < ceiling_y + r:
			pos[p].y = ceiling_y + r
			prev[p].y = pos[p].y
		if pos[p].x < wall_l + r:
			pos[p].x = wall_l + r
			prev[p].x = pos[p].x
		elif pos[p].x > wall_r - r:
			pos[p].x = wall_r - r
			prev[p].x = pos[p].x


func _clamp_bounds() -> void:
	for p in pos.size():
		var r := radius[p]
		var before := pos[p]
		pos[p].x = clampf(pos[p].x, wall_l + r, wall_r - r)
		pos[p].y = clampf(pos[p].y, ceiling_y + r, floor_y - r)
		if pos[p] != before:
			prev[p] = pos[p]


func _rotate_subtree(index: int, angle: float) -> void:
	var pivot := pos[def.bones[index].start_idx]
	for child in subtree[index]:
		var end := def.bones[child].end_idx
		pos[end] = pivot + (pos[end] - pivot).rotated(angle)


func _collect_subtree(index: int) -> PackedInt32Array:
	var result := PackedInt32Array([index])
	for i in def.bones.size():
		if def.bones[i].parent_index == index:
			result.append_array(_collect_subtree(i))
	return result


func pick(point: Vector2) -> Array:
	var head_bone := -1
	var neck_joint := -1
	for i in def.bones.size():
		if def.bones[i].id == &"head":
			head_bone = i
			neck_joint = def.bones[i].start_idx
			break
	if head_bone >= 0:
		var head_center := pos[neck_joint] + Vector2(0.0,
				-def.head_radius * view_scale)
		var head_radius := (def.head_radius + def.head_line_width) * view_scale
		if point.distance_to(head_center) <= head_radius:
			var neck_bone := -1
			for i in def.bones.size():
				if def.bones[i].id == &"neck":
					neck_bone = i
					break
			if neck_bone >= 0:
				# 头部圆只提供命中；物理抓点固定在 neck_top，避免大 offset 产生扭矩。
				return [neck_bone, 1.0, 0.0, Vector2.ZERO]

	var best := [-1, 0.0, INF, Vector2.ZERO]
	var best_priority := -1
	var priority_slack := 30.0 * view_scale
	for i in def.bones.size():
		var b := def.bones[i]
		var a := pos[b.start_idx]
		var c := pos[b.end_idx]
		var ab := c - a
		var t := clampf((point - a).dot(ab) / maxf(ab.length_squared(), 1e-4),
				0.0, 1.0)
		var d := point.distance_to(a + ab * t)
		var r := maxf(b.width * 2.4, 12.0) * view_scale
		if d > r:
			continue
		var priority := _pick_priority(b.id)
		var better := false
		if best[0] < 0:
			better = true
		elif priority > best_priority and d <= best[2] + priority_slack:
			# 肘/膝与躯干重叠时，优先抓肢体，避免点肘却抓到躯干。
			better = true
		elif priority == best_priority and d < best[2]:
			better = true
		if better:
			best = [i, t, d, Vector2.ZERO]
			best_priority = priority
	return best


func _pick_priority(bone_id: StringName) -> int:
	if bone_id in [&"upper_arm_l", &"upper_arm_r",
			&"forearm_l", &"forearm_r",
			&"thigh_l", &"thigh_r", &"shin_l", &"shin_r"]:
		return 3
	if bone_id == &"spine":
		return 1
	return 0


func begin_grab(bone: int, t: float, point: Vector2,
		local_offset: Vector2 = Vector2.ZERO) -> void:
	grab_bone = bone
	grab_t = t
	grab_local_offset = local_offset
	grab_target = point
	sleeping = false
	_rest_steps = 0
	damping = grab_damping


func end_grab() -> void:
	grab_bone = -1
	damping = 1.0


func damp_velocities(factor: float) -> void:
	for p in pos.size():
		var velocity := (pos[p] - prev[p]) * factor
		prev[p] = pos[p] - velocity


func damp_bone_motion(bone_ids: Array, factor: float) -> void:
	var seen := {}
	for b in def.bones:
		if not (b.id in bone_ids):
			continue
		for idx in [b.start_idx, b.end_idx]:
			if seen.has(idx):
				continue
			seen[idx] = true
			var velocity := (pos[idx] - prev[idx]) * factor
			prev[idx] = pos[idx] - velocity


func apply_velocity(bone: int, t: float, velocity: Vector2, h: float) -> void:
	if bone < 0:
		return
	var b := def.bones[bone]
	var near := b.start_idx if t <= 0.5 else b.end_idx
	var far := b.end_idx if t <= 0.5 else b.start_idx
	prev[near] -= velocity * h
	prev[far] -= velocity * (0.35 * h)


func is_resting() -> bool:
	var energy := 0.0
	for p in pos.size():
		energy += (pos[p] - prev[p]).length_squared()
	return energy < 0.2


func is_supported() -> bool:
	for p in pos.size():
		if pos[p].y >= floor_y - radius[p] - 2.0:
			return true
	return false


func sync_from_pose_from_pos() -> void:
	prev = pos.duplicate()
