class_name AnimPlayer
extends Node

signal clip_changed(clip_name: StringName)
signal event_fired(event_name: String)

var definition: RigDefinition
var library: AnimLibrary
var current: AnimClip
var time: float = 0.0
var additive_enabled: bool = true

var _current_rel: PackedFloat32Array = PackedFloat32Array()
var _previous_rel: PackedFloat32Array = PackedFloat32Array()
var _fade_left: float = 0.0
var _fade_duration: float = 0.0
var _has_previous: bool = false
var _breath_phase: float = 0.0
var _spine_index: int = -1
var _neck_index: int = -1


func setup(p_definition: RigDefinition, p_library: AnimLibrary) -> void:
	definition = p_definition
	library = p_library
	for i in definition.bones.size():
		if definition.bones[i].id == &"spine":
			_spine_index = i
		elif definition.bones[i].id == &"neck":
			_neck_index = i


func play(clip_name: StringName, fade: float = 0.2) -> bool:
	if library == null:
		return false
	var next := library.get_clip(clip_name)
	if next == null:
		push_warning("动画缺失: %s" % clip_name)
		return false
	if next == current:
		return true
	if not _current_rel.is_empty():
		_previous_rel = _current_rel.duplicate()
		_has_previous = true
		_fade_duration = maxf(fade, 0.0)
		_fade_left = _fade_duration
	else:
		_has_previous = false
		_fade_left = 0.0
	current = next
	time = 0.0
	clip_changed.emit(clip_name)
	return true


func apply(pose: RigPose) -> void:
	if current == null:
		return
	var target := PackedFloat32Array()
	PoseSampler.sample_rel(current, definition, time, target)
	if _has_previous and _fade_left > 0.0:
		var w := 1.0 - _fade_left / maxf(_fade_duration, 0.0001)
		PoseBlender.crossfade(_previous_rel, target, w, pose.rel)
	else:
		pose.rel = target
	_current_rel = pose.rel.duplicate()
	_apply_additive(pose.rel)


func tick(dt: float, pose: RigPose) -> void:
	if current == null:
		return
	var old_time := time
	time += dt
	_breath_phase = fposmod(_breath_phase + dt * TAU / 4.0, TAU)
	var fired: Dictionary = {}
	if current.loop:
		time = fposmod(time, current.length)
		_dispatch_events(current, old_time, current.length, fired)
		_dispatch_events(current, 0.0, time, fired)
	else:
		time = minf(time, current.length)
		_dispatch_events(current, old_time, time, fired)
	apply(pose)
	if _fade_left > 0.0:
		_fade_left = maxf(_fade_left - dt, 0.0)
		if _fade_left <= 0.0:
			_has_previous = false


func seek(normalized: float) -> void:
	if current == null:
		return
	time = clampf(normalized, 0.0, 1.0) * current.length
	_fade_left = 0.0
	_has_previous = false


func _apply_additive(rel: PackedFloat32Array) -> void:
	if not additive_enabled or rel.is_empty():
		return
	var add := PackedFloat32Array()
	add.resize(rel.size())
	var mask := PackedFloat32Array()
	mask.resize(rel.size())
	if _spine_index >= 0:
		add[_spine_index] = sin(_breath_phase) * 0.012
		mask[_spine_index] = 1.0
	if _neck_index >= 0:
		add[_neck_index] = sin(_breath_phase + 0.4) * 0.008
		mask[_neck_index] = 1.0
	PoseBlender.additive(rel, add, mask, 1.0)


func _dispatch_events(clip: AnimClip, from: float, to: float,
		fired: Dictionary) -> void:
	if to <= from and not (from > clip.length and clip.loop):
		return
	for event in clip.events:
		var t := float(event.get("t", -1.0))
		var event_name := str(event.get("name", ""))
		if t >= from and t <= to and not fired.has(event_name):
			fired[event_name] = true
			event_fired.emit(event_name)
