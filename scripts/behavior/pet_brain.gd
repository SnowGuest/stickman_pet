class_name PetBrain
extends Node

## 无鼠标交互的轻量自主行为调度器：只在待机/走路/挥手/观察之间切换。
## 不做路径寻找和物理；角色始终留在桌面原位。

signal state_changed(state: int, clip: StringName)
signal footstep

enum State { IDLE, WALK, WAVE, LOOK }

const CLIP_BY_STATE := {
	State.IDLE: &"idle",
	State.WALK: &"walk",
	State.WAVE: &"wave",
	State.LOOK: &"idle",
}

var state: State = State.IDLE
var state_time: float = 0.0
var look_angle: float = 0.0
var energy: float = 0.85
var boredom: float = 0.15
var curiosity: float = 0.60


func body_bob() -> float:
	# 走路时轻微上下起伏；不改变骨骼长度和接触阴影。
	if state != State.WALK:
		return 0.0
	return -absf(sin(state_time * 8.0)) * 1.6

var _anim: AnimPlayer
var _rng := RandomNumberGenerator.new()
var _duration: float = 8.0
var _forced: bool = false
var _step_acc: float = 0.0

const DURATION_RANGES := {
	State.IDLE: Vector2(7.0, 14.0),
	State.WALK: Vector2(3.5, 6.0),
	State.WAVE: Vector2(2.6, 2.6),
	State.LOOK: Vector2(2.5, 4.0),
}

const NEXT_WEIGHTS := {
	State.IDLE: [[State.WALK, 0.45], [State.WAVE, 0.25], [State.LOOK, 0.30]],
	State.WALK: [[State.IDLE, 0.65], [State.WAVE, 0.15], [State.LOOK, 0.20]],
	State.WAVE: [[State.IDLE, 0.80], [State.WALK, 0.20]],
	State.LOOK: [[State.IDLE, 0.70], [State.WALK, 0.30]],
}


func setup(anim_player: AnimPlayer, rng_seed: int = 20261020) -> void:
	_anim = anim_player
	_rng.seed = rng_seed
	_enter(State.IDLE)


func tick(dt: float) -> void:
	if _anim == null:
		return
	state_time += dt
	energy = clampf(energy - dt * (0.004 if state == State.WALK else 0.0015),
			0.0, 1.0)
	boredom = clampf(boredom + dt * (0.010 if state == State.IDLE else 0.003),
			0.0, 1.0)
	curiosity = clampf(curiosity + dt * 0.002, 0.0, 1.0)
	if state == State.LOOK:
		# 无脸表演：只转头/上身，不做眼部或面部动画。
		look_angle = sin(state_time * 1.6) * deg_to_rad(18.0)
	else:
		look_angle = move_toward(look_angle, 0.0, dt * 2.0)
	if state == State.WALK:
		_step_acc += dt
		if _step_acc >= 0.5:
			_step_acc = 0.0
			footstep.emit()
	else:
		_step_acc = 0.0
	if _forced:
		return
	if state_time < _duration:
		return
	_enter(_pick_next())


func force(next_state: State) -> void:
	_forced = true
	_enter(next_state)


func release_force() -> void:
	_forced = false


func _enter(next_state: State) -> void:
	state = next_state
	state_time = 0.0
	look_angle = 0.0
	var duration_range: Vector2 = DURATION_RANGES[next_state]
	_duration = _rng.randf_range(duration_range.x, duration_range.y)
	var clip := StringName(CLIP_BY_STATE[next_state])
	if _anim != null:
		_anim.play(clip, 0.2)
	state_changed.emit(state, clip)


func _pick_next() -> State:
	var options: Array = NEXT_WEIGHTS[state]
	var weighted: Array = []
	var total := 0.0
	for option in options:
		var next_state: State = option[0]
		var weight := float(option[1])
		match next_state:
			State.WALK:
				weight *= (0.65 + boredom * 0.8) * (0.6 + energy)
			State.WAVE:
				weight *= (0.7 + curiosity * 0.5)
			State.LOOK:
				weight *= (0.6 + curiosity)
			State.IDLE:
				weight *= (1.4 - energy * 0.5)
		weighted.append([next_state, weight])
		total += weight
	var roll := _rng.randf() * total
	for option in weighted:
		roll -= float(option[1])
		if roll <= 0.0:
			return option[0]
	return State.IDLE
