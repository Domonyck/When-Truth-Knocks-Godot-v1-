extends Panel

var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

@onready var title_bar: Panel = $Panel

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Check if the click is inside the title bar bounds
			var title_global_rect = Rect2(title_bar.global_position, title_bar.size)
			if title_global_rect.has_point(get_global_mouse_position()):
				dragging = true
				drag_offset = get_global_mouse_position() - global_position
		else:
			dragging = false
			
	elif event is InputEventMouseMotion and dragging:
		global_position = get_global_mouse_position() - drag_offset
