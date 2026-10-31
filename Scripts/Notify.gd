extends CanvasLayer

var _label: Label
var _panel: PanelContainer
var _tween: Tween

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Use a Control container set to full rect so we can place elements anywhere using anchors
	var root_control := Control.new()
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.modulate.a = 0.0
	
	# Anchor the panel to the top-left with custom offsets/margins (e.g., 24 pixels from the corner)
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.offset_left = 24
	_panel.offset_top = 24
	root_control.add_child(_panel)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 36)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_panel.add_child(_label)

func show_message(text: String, duration: float = 2.0) -> void:
	_label.text = text
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 1.0, 0.25)
	_tween.tween_interval(duration)
	_tween.tween_property(_panel, "modulate:a", 0.0, 0.4)
