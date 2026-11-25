
extends CanvasLayer
const TYPEWRITER_FONT: FontFile = preload("res://WindowsDesktop/JMH Typewriter.otf")
var _label: Label
var _timer_label: Label
var _panel: PanelContainer
var _tween: Tween

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	var root_control := Control.new()
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.modulate.a = 0.0

	# Remove the panel's black background
	var transparent_style := StyleBoxEmpty.new()
	_panel.add_theme_stylebox_override("panel", transparent_style)

	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.offset_left = 24
	_panel.offset_top = 24
	root_control.add_child(_panel)

	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)
	_panel.add_child(container)

	_label = Label.new()
	_label.add_theme_font_override("font", TYPEWRITER_FONT)
	_label.add_theme_font_size_override("font_size", 36)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.add_theme_color_override("font_color", Color.WHITE)
	container.add_child(_label)

	_timer_label = Label.new()
	_label.add_theme_font_override("font", TYPEWRITER_FONT)
	_timer_label.add_theme_font_size_override("font_size", 18)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_timer_label.add_theme_color_override("font_color", Color.WHITE)
	container.add_child(_timer_label)


func show_message(text: String, duration: float = 5.0) -> void:
	_label.text = text

	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()

	_panel.modulate.a = 1.0

	# Update countdown
	var remaining := duration

	while remaining > 0.0:
		await get_tree().create_timer(0.1).timeout
		remaining -= 0.1

	# Fade out after countdown
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 0.0, 0.4)
