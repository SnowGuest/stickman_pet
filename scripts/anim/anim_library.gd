class_name AnimLibrary
extends RefCounted

var clips: Dictionary = {}
var errors: Array[String] = []


func load_dir(path: String, definition: RigDefinition) -> bool:
	clips.clear()
	errors.clear()
	var files := DirAccess.get_files_at(path)
	for file in files:
		if not file.ends_with(".json"):
			continue
		var full := path.path_join(file)
		var raw := FileAccess.get_file_as_string(full)
		var data = JSON.parse_string(raw)
		if not (data is Dictionary):
			errors.append("%s: invalid JSON" % file)
			continue
		var clip := AnimClip.new()
		var error := clip.load_from_dict(data, definition)
		if not error.is_empty():
			errors.append("%s: %s" % [file, error])
			continue
		clips[clip.id] = clip
	return not clips.is_empty()


func get_clip(id: StringName) -> AnimClip:
	return clips.get(id, null)


func names() -> Array[StringName]:
	var result: Array[StringName] = []
	for key in clips:
		result.append(key)
	result.sort()
	return result
