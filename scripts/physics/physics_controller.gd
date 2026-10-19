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


func setup(p_definition: RigDefinition) -> void:
	definition = p_definition
	solver = RagdollSolver.new()
	solver.build(definition)


func start(pose: RigPose, floor: float, left: float, right: float) -> void:
	solver.start_from_pose(pose, floor, left, right)
	solver.sleeping = false
	_acc = 0.0
	_rest_steps = 0
	active = true
	grabbing = false


func begin_drag(local: Vector2, floor: float, left: float, right: float) -> bool:
	if not active:
		# caller supplies current pose via start_with_pose
		return false
	var hit := solver.pick(local)
	if int(hit[0]) < 0:
		return false
	var bone := int(hit[0])
	var t := float(hit[1])
	var point := solver.pos[definition.bones[bone].start_idx].lerp(
			solver.pos[definition.bones[bone].end_idx], t)
	solver.begin_grab(bone, t, point)
	_grab_offset = local - point
	_last_target = local
	_velocity = Vector2.ZERO
	_last_delta = 1.0 / 60.0
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
	solver.grab_target = local + _grab_offset


func end_drag() -> void:
	if not grabbing:
		return
	solver.apply_velocity(solver.grab_bone, solver.grab_t, _velocity, H)
	solver.end_grab()
	grabbing = false


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
	_acc += minf(dt, 1.0 / 30.0)
	var guard := 0
	while _acc >= H and guard < 4:
		_acc -= H
		solver.step(H)
		guard += 1
	if solver.is_resting():
		_rest_steps += 1
		if _rest_steps >= 120 and not grabbing:
			solver.sleeping = true
	else:
		_rest_steps = 0
	solver.write_pose(pose)
