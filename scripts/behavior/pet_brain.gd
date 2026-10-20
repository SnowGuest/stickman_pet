class_name PetBrain
extends Node

## 无鼠标交互的轻量自主行为调度器：只在待机/走路/挥手/观察之间切换。
## 不做路径寻找和物理；角色始终留在桌面原位。

signal state_changed(state: int, clip: StringName)

enum State { IDLE, WALK, WAVE, LOOK }

const CLIP_BY_STATE := {
	State.IDLE: &"idle",
	State.WALK: &"walk",
	State.WAVE: &"wave",
	State.LOOK: &"idle",
}

var state: State = State.IDLE
var state_time: float = 0.0

var _anim: AnimPlayer
var _rng := RandomNumberGenerator.new()
var _duration: float = 8.0
var _forced: bool = false

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
	var duration_range: Vector2 = DURATION_RANGES[next_state]
	_duration = _rng.randf_range(duration_range.x, duration_range.y)
	var clip := StringName(CLIP_BY_STATE[next_state])
	if _anim != null:
		_anim.play(clip, 0.2)
	state_changed.emit(state, clip)


func _pick_next() -> State:
	var options: Array = NEXT_WEIGHTS[state]
	var total := 0.0
	for option in options:
		total += float(option[1])
	var roll := _rng.randf() * total
	for option in options:
		roll -= float(option[1])
		if roll <= 0.0:
			return option[0]
	return State.IDLE
