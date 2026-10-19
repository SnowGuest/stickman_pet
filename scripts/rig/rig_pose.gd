class_name RigPose
extends RefCounted

var root_pos: Vector2 = Vector2.ZERO
var root_angle: float = 0.0
var rel: PackedFloat32Array = PackedFloat32Array()
var abs_angle: PackedFloat32Array = PackedFloat32Array()
var joint_pos: PackedVector2Array = PackedVector2Array()


func reset_rest(definition: RigDefinition) -> void:
	rel.resize(definition.bones.size())
	for i in definition.bones.size():
		rel[i] = definition.bones[i].rest_rel
