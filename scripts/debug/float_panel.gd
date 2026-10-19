class_name FloatPanel
extends PanelContainer

signal scale_changed(value: float)
signal line_width_changed(value: float)
signal palette_selected(name: String)
signal skeleton_toggled(enabled: bool)

var _scale: HSlider
var _width: HSlider
var _palette: OptionButton
var _skeleton: CheckBox


func setup(initial_scale: float, initial_width: float, palette_names: Array,
		palette_index: int) -> void:
	position = Vector2(16.0, 16.0)
	custom_minimum_size = Vector2(280.0, 0.0)
	z_index = 300

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	var title := Label.new()
	title.text = "调试参数"
	box.add_child(title)

	var scale_label := Label.new()
	scale_label.text = "缩放 %.2f" % initial_scale
	box.add_child(scale_label)
	_scale = HSlider.new()
	_scale.min_value = 0.8
	_scale.max_value = 2.0
	_scale.step = 0.05
	_scale.value = initial_scale
	box.add_child(_scale)
	_scale.value_changed.connect(func(value: float) -> void:
		scale_label.text = "缩放 %.2f" % value
		scale_changed.emit(value))

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
