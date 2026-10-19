class_name PoseSampler
extends RefCounted


static func sample_rel(clip: AnimClip, definition: RigDefinition,
		t: float, out: PackedFloat32Array) -> void:
	var abs := PackedFloat32Array()
	abs.resize(definition.bones.size())
	for i in definition.bones.size():
		abs[i] = definition.bones[i].rest_abs_deg
	for bone_id in clip.tracks:
		var index := -1
		for i in definition.bones.size():
			if definition.bones[i].id == bone_id:
				index = i
				break
		if index < 0:
			continue
		abs[index] = _sample(clip.tracks[bone_id], t, clip.length, clip.loop,
				definition.bones[index].rest_abs_deg)
	to_relative(abs, definition, out)


static func _sample(keys: Array, t: float, length: float, loop: bool,
		fallback: float) -> float:
	if keys.is_empty():
		return fallback
	var tt := fposmod(t, length) if loop else clampf(t, 0.0, length)
	if keys.size() == 1 or tt <= float(keys[0][0]):
		return float(keys[0][1])
	if tt >= float(keys[-1][0]):
		return float(keys[-1][1])
	var lo := 0
	var hi := keys.size() - 1
	while lo < hi - 1:
		var mid := (lo + hi) >> 1
		if float(keys[mid][0]) <= tt:
			lo = mid
		else:
			hi = mid
	var t0 := float(keys[lo][0])
	var t1 := float(keys[hi][0])
	var w := (tt - t0) / maxf(t1 - t0, 0.0001)
	w = w * w * (3.0 - 2.0 * w)
	return rad_to_deg(lerp_angle(deg_to_rad(float(keys[lo][1])),
			deg_to_rad(float(keys[hi][1])), w))


static func to_relative(abs_deg: PackedFloat32Array,
		definition: RigDefinition, out: PackedFloat32Array) -> void:
	out.resize(abs_deg.size())
	for i in definition.topo_order:
		var bone := definition.bones[i]
		var parent_abs := 0.0
		if bone.parent_index >= 0:
			parent_abs = abs_deg[bone.parent_index]
		out[i] = deg_to_rad(wrapf(abs_deg[i] - parent_abs, -180.0, 180.0))
