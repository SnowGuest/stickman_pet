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
var subtree: Array[PackedInt32Array] = []

var grab_bone: int = -1
var grab_t: float = 0.5
var grab_target: Vector2 = Vector2.ZERO
var grab_strength: float = 0.55

var gravity: float = 1200.0
var damping: float = 0.996
var iterations: int = 8
var max_corr: float = 0.20
var floor_y: float = 1000.0
var ceiling_y: float = 0.0
var wall_l: float = 2.0
var wall_r: float = 1918.0
var restitution: float = 0.22
var friction: float = 0.35
var root_angle: float = 0.0
var sleeping: bool = false


func build(definition: RigDefinition) -> void:
	def = definition
	var n := def.joints.size()
	pos.resize(n)
	prev.resize(n)
	inv_mass.resize(n)
	radius.resize(n)
	drive_rel.resize(def.bones.size())
	tone.resize(def.bones.size())
	world_bias.resize(def.bones.size())
	bias_abs.resize(def.bones.size())
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


func sync_from_pose(pose: RigPose) -> void:
	pos = pose.joint_pos.duplicate()
	prev = pos.duplicate()
	sleeping = false


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
	sync_from_pose(pose)
	for i in def.bones.size():
		drive_rel[i] = pose.rel[i]
		tone[i] = 0.03
		world_bias[i] = 0.0
		bias_abs[i] = 0.0
	var spine_bone := -1
	for i in def.bones.size():
		if def.bones[i].id == &"spine":
			spine_bone = i
			break
	if spine_bone >= 0:
		world_bias[spine_bone] = 0.45
		bias_abs[spine_bone] = -PI * 0.5


func step(h: float) -> void:
	if sleeping or def == null or pos.is_empty():
		return
	_integrate(h)
	for _i in iterations:
		_solve_angles()
		_solve_distances()
		_solve_grab()
		_solve_collisions()
	# 最后一次角度/碰撞可能轻微拉伸骨长，收尾再投影回距离约束。
	for _i in 2:
		_solve_distances()
	# 抓取点最后再收一次，保证指针位置优先于骨长残差。
	for _i in 8:
		_solve_grab()
	# 所有约束结束后再做一次硬边界夹取，任何约束都不能把角色推出屏幕。
	_solve_collisions()
	_clamp_bounds()
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
		var wa := inv_mass[a]
		var wc := inv_mass[c]
		var wsum := wa + wc
		if wsum <= 0.0:
			continue
		var corr := delta * ((dist - b.length) / dist)
		pos[a] += corr * (wa / wsum)
		pos[c] -= corr * (wc / wsum)


func _solve_angles() -> void:
	for i in def.topo_order:
		var b := def.bones[i]
		# spine/thigh 的 parent 为空，其 rest/limit 是相对骨盆的旧表；
		# P3 首版先让它们自由摆动，子骨骼仍受限位保护。
		if b.parent_index < 0:
			if b.id == &"spine" and world_bias[i] > 0.0:
				_solve_world_bias(i, b)
			continue
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
		var target := clampf(drive_rel[i] if i < drive_rel.size() else b.rest_rel,
				b.lo, b.hi)
		var err := 0.0
		var k := 0.0
		if rel < b.lo:
			err = b.lo - rel
			k = 1.0
		elif rel > b.hi:
			err = b.hi - rel
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


func _solve_grab() -> void:
	if grab_bone < 0:
		return
	var b := def.bones[grab_bone]
	var a := b.start_idx
	var c := b.end_idx
	var t := clampf(grab_t, 0.0, 1.0)
	var cur := pos[a].lerp(pos[c], t)
	var target := grab_target
	target.x = clampf(target.x, wall_l, wall_r)
	target.y = clampf(target.y, ceiling_y, floor_y)
	var delta := (target - cur) * grab_strength
	var norm := 1.0 / maxf((1.0 - t) * (1.0 - t) + t * t, 1e-4)
	pos[a] += delta * (1.0 - t) * norm
	pos[c] += delta * t * norm


func _solve_collisions() -> void:
	for p in pos.size():
		var r := radius[p]
		if pos[p].y > floor_y - r:
			var vy := pos[p].y - prev[p].y
			pos[p].y = floor_y - r
			if vy > 2.0:
				prev[p].y = pos[p].y + restitution * vy
			else:
				prev[p].y = pos[p].y
			prev[p].x = lerpf(prev[p].x, pos[p].x, friction)
		if pos[p].y < ceiling_y + r:
			pos[p].y = ceiling_y + r
			prev[p].y = pos[p].y
		if pos[p].x < wall_l + r:
			pos[p].x = wall_l + r
			prev[p].x = pos[p].x + restitution * (pos[p].x - prev[p].x)
		elif pos[p].x > wall_r - r:
			pos[p].x = wall_r - r
			prev[p].x = pos[p].x + restitution * (pos[p].x - prev[p].x)


func _clamp_bounds() -> void:
	for p in pos.size():
		var r := radius[p]
		pos[p].x = clampf(pos[p].x, wall_l + r, wall_r - r)
		pos[p].y = clampf(pos[p].y, ceiling_y + r, floor_y - r)


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
	var best := [-1, 0.0, INF]
	for i in def.bones.size():
		var b := def.bones[i]
		var a := pos[b.start_idx]
		var c := pos[b.end_idx]
		var ab := c - a
		var t := clampf((point - a).dot(ab) / maxf(ab.length_squared(), 1e-4),
				0.0, 1.0)
		var d := point.distance_to(a + ab * t)
		var r := maxf(b.width * 2.4, 12.0) * def.base_scale
		if d <= r and d < best[2]:
			best = [i, t, d]
	return best


func begin_grab(bone: int, t: float, point: Vector2) -> void:
	grab_bone = bone
	grab_t = t
	grab_target = point
	sleeping = false


func end_grab() -> void:
	grab_bone = -1


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
	return energy < 0.02


func sync_from_pose_from_pos() -> void:
	prev = pos.duplicate()
