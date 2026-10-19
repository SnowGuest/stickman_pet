class_name RigState
extends RefCounted


static func resolve(definition: RigDefinition, pose: RigPose) -> void:
	if definition == null or pose == null:
		return
	pose.joint_pos.resize(definition.joints.size())
	pose.abs_angle.resize(definition.bones.size())
	var pelvis := int(definition.joint_index.get(&"pelvis", 0))
	pose.joint_pos[pelvis] = pose.root_pos

	for i in definition.topo_order:
		var bone := definition.bones[i]
		var parent_abs := pose.root_angle if bone.parent_index < 0 \
				else pose.abs_angle[bone.parent_index]
		var angle := wrapf(parent_abs + pose.rel[i], -PI, PI)
		pose.abs_angle[i] = angle
		pose.joint_pos[bone.end_idx] = pose.joint_pos[bone.start_idx] \
				+ Vector2.from_angle(angle) * bone.length
