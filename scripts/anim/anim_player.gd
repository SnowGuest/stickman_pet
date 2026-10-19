class_name AnimPlayer
extends Node

signal clip_changed(clip_name: StringName)
signal event_fired(event_name: String)

var definition: RigDefinition
var library: AnimLibrary
var current: AnimClip
var time: float = 0.0

var _current_rel: PackedFloat32Array = PackedFloat32Array()
var _previous_rel: PackedFloat32Array = PackedFloat32Array()
var _fade_left: float = 0.0
var _fade_duration: float = 0.0
var _has_previous: bool = false


func setup(p_definition: RigDefinition, p_library: AnimLibrary) -> void:
	definition = p_definition
	library = p_library


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


func tick(dt: float, pose: RigPose) -> void:
	if current == null:
		return
	var old_time := time
	time += dt
	if current.loop:
		time = fposmod(time, current.length)
		_dispatch_events(current, old_time, current.length)
		_dispatch_events(current, 0.0, time)
	else:
		time = minf(time, current.length)
		_dispatch_events(current, old_time, time)
	apply(pose)
	if _fade_left > 0.0:
		_fade_left = maxf(_fade_left - dt, 0.0)
		if _fade_left <= 0.0:
			_has_previous = false


func _dispatch_events(clip: AnimClip, from: float, to: float) -> void:
	if to <= from and not (from > clip.length and clip.loop):
		return
	for event in clip.events:
		var t := float(event.get("t", -1.0))
		if t >= from and t <= to:
			event_fired.emit(str(event.get("name", "")))
