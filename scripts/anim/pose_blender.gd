class_name PoseBlender
extends RefCounted


static func crossfade(a: PackedFloat32Array, b: PackedFloat32Array,
		weight: float, out: PackedFloat32Array) -> void:
	out.resize(b.size())
	var w := clampf(weight, 0.0, 1.0)
	for i in b.size():
		var from := a[i] if i < a.size() else b[i]
		out[i] = from + wrapf(b[i] - from, -PI, PI) * w


static func additive(base: PackedFloat32Array, add: PackedFloat32Array,
		mask: PackedFloat32Array, weight: float) -> void:
	var w := clampf(weight, 0.0, 1.0)
	for i in base.size():
		if i >= add.size() or i >= mask.size():
			break
		base[i] += add[i] * mask[i] * w
