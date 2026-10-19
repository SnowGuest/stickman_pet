class_name DebugOverlay
extends Node2D

signal palette_cycle
signal animation_selected(name: StringName)

var definition: RigDefinition
var pose: RigPose
var renderer: StickRenderer
var passthrough: PassthroughService

var show_skeleton: bool = true
var show_passthrough: bool = false
var highlight_bones: Dictionary = {}


func setup(p_definition: RigDefinition, p_pose: RigPose, p_renderer: StickRenderer,
		p_passthrough: PassthroughService) -> void:
	definition = p_definition
	pose = p_pose
	renderer = p_renderer
	passthrough = p_passthrough
	z_index = 100


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F1:
			show_skeleton = not show_skeleton
		KEY_F2:
			animation_selected.emit(&"idle")
		KEY_F3:
			animation_selected.emit(&"walk")
		KEY_F4:
			animation_selected.emit(&"drag_idle")
		KEY_F5:
			animation_selected.emit(&"wave")
		KEY_F6:
			palette_cycle.emit()
		KEY_F7:
			show_passthrough = not show_passthrough


func _process(_dt: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if pose == null or definition == null:
		return
	if show_skeleton:
		var scale := renderer.scale if renderer != null else Vector2.ONE
		for joint in pose.joint_pos:
			var point := pose.root_pos + (joint - pose.root_pos) * scale
			draw_circle(point, 3.0, Color(1.0, 0.2, 0.2, 0.9))
		for bone in definition.bones:
			if not highlight_bones.has(bone.id):
				continue
			var a := pose.root_pos + (pose.joint_pos[bone.start_idx]
					- pose.root_pos) * scale
			var b := pose.root_pos + (pose.joint_pos[bone.end_idx]
					- pose.root_pos) * scale
			draw_line(a, b, Color(1.0, 0.9, 0.1, 0.9), 2.0, true)
	if show_passthrough and passthrough != null:
		var region := passthrough.get_last_region()
		if region.size() > 2:
			draw_polyline(region, Color(0.0, 1.0, 1.0, 0.8), 1.0, true)
