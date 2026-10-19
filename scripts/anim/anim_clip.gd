class_name AnimClip
extends RefCounted

var id: StringName = &""
var length: float = 1.0
var loop: bool = true
var tracks: Dictionary = {}
var events: Array = []


func load_from_dict(data: Dictionary, definition: RigDefinition) -> String:
	if definition == null:
		return "missing rig"
	id = StringName(str(data.get("name", "")))
	if id == &"":
		return "missing name"
	length = maxf(float(data.get("length", 1.0)), 0.001)
	loop = bool(data.get("loop", true))
	tracks.clear()
	var raw_tracks = data.get("tracks", {})
	if not (raw_tracks is Dictionary):
		return "tracks must be object"
	for bone_id in raw_tracks:
		var key := StringName(str(bone_id))
		var known := false
		for bone in definition.bones:
			if bone.id == key:
				known = true
				break
		if not known:
			return "unknown bone: %s" % key
		var keys = raw_tracks[bone_id]
		if not (keys is Array) or keys.is_empty():
			return "empty track: %s" % key
		var parsed: Array = []
		var last_time := -1.0
		for item in keys:
			if not (item is Array) or item.size() < 2:
				return "bad key: %s" % key
			var t := float(item[0])
			var angle := float(item[1])
			if t < 0.0 or t < last_time:
				return "time not ascending: %s" % key
			last_time = t
			parsed.append([t, angle])
		if loop and absf(float(parsed[0][1]) - float(parsed[-1][1])) > 0.01:
			return "loop not closed: %s" % key
		tracks[key] = parsed

	events.clear()
	for item in data.get("events", []):
		if not (item is Dictionary):
			return "bad event"
		var t := float(item.get("t", -1.0))
		if t < 0.0 or t > length:
			return "event out of range"
		events.append({"t": t, "name": str(item.get("name", ""))})
	return ""
