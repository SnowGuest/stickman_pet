class_name FloatPanel
extends PanelContainer

signal line_width_changed(value: float)
signal palette_selected(name: String)
signal skeleton_toggled(enabled: bool)
signal animation_selected(name: StringName)
signal animation_time_seek(normalized: float)

var _width: HSlider
var _palette: OptionButton
var _skeleton: CheckBox
var _anim: OptionButton
var _anim_time: HSlider
var _anim_time_label: Label
var _anim_names: Array = []


func setup(initial_width: float, palette_names: Array,
		palette_index: int, anim_names: Array = [],
		anim_index: int = 0) -> void:
	position = Vector2(16.0, 16.0)
	custom_minimum_size = Vector2(280.0, 0.0)
	z_index = 300

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	var title := Label.new()
	title.text = "调试参数"
	box.add_child(title)

	_anim = OptionButton.new()
	_anim_names = anim_names.duplicate()
	for item in anim_names:
		_anim.add_item(str(item))
	_anim.selected = clampi(anim_index, 0, maxi(0, _anim.item_count - 1))
	_anim.disabled = anim_names.is_empty()
	box.add_child(_anim)
	_anim.item_selected.connect(func(index: int) -> void:
		if index >= 0 and index < _anim_names.size():
			animation_selected.emit(StringName(str(_anim_names[index]))))

	_anim_time_label = Label.new()
	_anim_time_label.text = "动画时间 0%"
	box.add_child(_anim_time_label)
	_anim_time = HSlider.new()
	_anim_time.min_value = 0.0
	_anim_time.max_value = 1.0
	_anim_time.step = 0.001
	_anim_time.value = 0.0
	_anim_time.editable = not anim_names.is_empty()
	box.add_child(_anim_time)
	_anim_time.value_changed.connect(func(value: float) -> void:
		_anim_time_label.text = "动画时间 %d%%" % int(value * 100.0)
		animation_time_seek.emit(value))

	var width_label := Label.new()
	width_label.text = "线宽 %.1f" % initial_width
	box.add_child(width_label)
	_width = HSlider.new()
	_width.min_value = 2.0
	_width.max_value = 12.0
	_width.step = 0.5
	_width.value = initial_width
	box.add_child(_width)
	_width.value_changed.connect(func(value: float) -> void:
		width_label.text = "线宽 %.1f" % value
		line_width_changed.emit(value))

	_palette = OptionButton.new()
	for item in palette_names:
		_palette.add_item(str(item))
	_palette.selected = clampi(palette_index, 0, maxi(0, _palette.item_count - 1))
	box.add_child(_palette)
	_palette.item_selected.connect(func(index: int) -> void:
		palette_selected.emit(str(palette_names[index])))

	_skeleton = CheckBox.new()
	_skeleton.text = "显示骨架点"
	_skeleton.button_pressed = true
	box.add_child(_skeleton)
	_skeleton.toggled.connect(func(enabled: bool) -> void:
		skeleton_toggled.emit(enabled))


func set_animation_selected(name: StringName) -> void:
	if _anim == null:
		return
	var index := _anim_names.find(name)
	if index >= 0:
		_anim.select(index)
