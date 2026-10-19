extends SceneTree

## P0 工程基线测试。
## 不依赖外部框架；由 tools/gate.ps1 -Full 以 --script 运行。

var _checks := 0
var _failures := 0


func _initialize() -> void:
	print("[tests] P0 engineering baseline")
	_test_project_settings()
	_test_main_scene()
	_test_theme()
	_test_icons()
	_test_audio()
	_test_rig()
	_test_palette()
	print("[tests] checks=%d failures=%d" % [_checks, _failures])
	if _failures > 0:
		push_error("[tests] FAIL")
		quit(1)
	else:
		print("[tests] PASS")
		quit(0)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if ok:
		print("  PASS  " + label)
	else:
		_failures += 1
		push_error("  FAIL  " + label)


func _setting(key: String, fallback = null):
	return ProjectSettings.get_setting(key, fallback)


func _test_project_settings() -> void:
	_check(str(_setting("application/config/name", "")) == "Stickman Pet",
			"application/config/name")
	_check(str(_setting("application/run/main_scene", "")) == "res://scenes/main.tscn",
			"main scene path")
	_check(str(_setting("application/config/icon", "")) == "res://assets/icons/icon_512.png",
			"project icon path")
	_check(bool(_setting("display/window/size/transparent", false)), "transparent window")
	_check(bool(_setting("display/window/per_pixel_transparency/allowed", false)),
			"per-pixel transparency")
	_check(bool(_setting("display/window/size/borderless", false)), "borderless")
	_check(bool(_setting("display/window/size/always_on_top", false)), "always on top")
	_check(not bool(_setting("display/window/size/resizable", true)), "not resizable")
	_check(str(_setting("display/window/stretch/mode", "disabled")) == "disabled",
			"stretch disabled")
	_check(int(_setting("display/window/size/viewport_width", 0)) == 1280,
			"viewport width 1280")
	_check(int(_setting("display/window/size/viewport_height", 0)) == 720,
			"viewport height 720")
	_check(str(_setting("gui/theme/custom", "")) == "res://assets/themes/pet_theme.tres",
			"global theme")
	_check(int(_setting("debug/gdscript/warnings/untyped_declaration", -1)) == 1,
			"warning: untyped declaration")
	_check(int(_setting("debug/gdscript/warnings/unsafe_property_access", -1)) == 1,
			"warning: unsafe property")
	_check(int(_setting("debug/gdscript/warnings/unsafe_method_access", -1)) == 1,
			"warning: unsafe method")
	_check(int(_setting("debug/gdscript/warnings/unsafe_cast", -1)) == 1,
			"warning: unsafe cast")
	_check(int(_setting("debug/gdscript/warnings/unsafe_call_argument", -1)) == 1,
			"warning: unsafe call argument")
	_check(int(_setting("debug/gdscript/warnings/return_value_discarded", -1)) == 1,
			"warning: discarded return value")


func _test_main_scene() -> void:
	var path := "res://scenes/main.tscn"
	_check(ResourceLoader.exists(path), "main scene exists")
	var scene = load(path)
	_check(scene is PackedScene, "main scene loads as PackedScene")
	if scene is PackedScene:
		var instance = scene.instantiate()
		_check(instance != null, "main scene instantiates")
		if instance != null:
			instance.free()


func _test_theme() -> void:
	var theme = load("res://assets/themes/pet_theme.tres")
	_check(theme is Theme, "theme loads")
	if theme is Theme:
		var font = theme.default_font
		_check(font is Font, "theme default font")
		if font is Font:
			_check(font.has_char("火".unicode_at(0)), "font has CJK glyph 火")
			_check(font.has_char("宠".unicode_at(0)), "font has CJK glyph 宠")


func _test_icons() -> void:
	var icon = load("res://assets/icons/icon_512.png")
	_check(icon is Texture2D, "icon_512 loads")
	if icon is Texture2D:
		_check(icon.get_width() == 512 and icon.get_height() == 512,
				"icon_512 is 512x512")
	_check(FileAccess.file_exists("res://assets/icons/icon.ico"), "icon.ico exists")
	_check(FileAccess.file_exists("res://assets/icons/tray.ico"), "tray.ico exists")


func _test_audio() -> void:
	var paths := [
		"res://assets/sfx/sfx_step_01.ogg",
		"res://assets/sfx/sfx_land_soft.ogg",
		"res://assets/sfx/sfx_wave_whoosh.ogg",
		"res://assets/sfx/sfx_sit.ogg",
		"res://assets/sfx/sfx_wave.ogg",
		"res://assets/sfx/sfx_clap.ogg",
		"res://assets/sfx/sfx_pop.ogg",
	]
	for path in paths:
		var stream = load(path)
		_check(stream is AudioStreamOggVorbis, "audio loads: " + path.get_file())
		if stream is AudioStreamOggVorbis:
			_check(stream.get_length() > 0.0, "audio length: " + path.get_file())

	var wave = load("res://assets/sfx/sfx_wave.ogg")
	_check(wave is AudioStreamOggVorbis and wave.loop, "wave loop enabled")
	var whoosh = load("res://assets/sfx/sfx_wave_whoosh.ogg")
	_check(whoosh is AudioStreamOggVorbis and not whoosh.loop, "whoosh not looped")


func _test_rig() -> void:
	var raw := FileAccess.get_file_as_string("res://assets/rigs/stickman.json")
	var data = JSON.parse_string(raw)
	_check(data is Dictionary, "rig json parses")
	if not (data is Dictionary):
		return
	var bones = data.get("bones", [])
	var joints = data.get("joints", [])
	_check(bones.size() == 13, "rig has 13 bones")
	_check(joints.size() == 14, "rig has 14 joints")
	_check(is_equal_approx(float(data.get("head_radius", 0.0)), 18.0),
			"rig head_radius is 18")
	var seen := {}
	var parent_order_ok := true
	for bone in bones:
		var parent := str(bone.get("parent", ""))
		if parent != "" and not seen.has(parent):
			parent_order_ok = false
		seen[str(bone.get("id", ""))] = true
	_check(parent_order_ok, "rig parent order")


func _test_palette() -> void:
	var raw := FileAccess.get_file_as_string("res://assets/palettes/stickman_palette.json")
	var data = JSON.parse_string(raw)
	_check(data is Dictionary, "palette json parses")
	if not (data is Dictionary):
		return
	_check(str(data.get("default", "")) == "orange", "palette default orange")
	var palettes = data.get("palettes", {})
	_check(palettes.size() == 5, "palette has 5 colors")
	var orange = palettes.get("orange", {})
	_check(str(orange.get("head", "")) == "hollow", "orange head is hollow")
