
extends Panel

var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var has_opened_before: bool = false

@onready var title_bar: Panel = $Panel


func _ready() -> void:
	hide()


# Call this function when the player interacts with the computer.
func open_computer() -> void:
	if not has_opened_before:
		show()
		has_opened_before = true


# Call this function when the player closes the computer.
func close_computer() -> void:
	hide()
	dragging = false


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:

			if event.pressed:
				var mouse_position = get_global_mouse_position()
				var title_rect = Rect2(
					title_bar.global_position,
					title_bar.size
				)

				if title_rect.has_point(mouse_position):
					dragging = true
					drag_offset = mouse_position - global_position

					# Prevent other UI elements from receiving the click.
					get_viewport().set_input_as_handled()

			else:
				dragging = false

	elif event is InputEventMouseMotion and dragging:
		global_position = get_global_mouse_position() - drag_offset
		get_viewport().set_input_as_handled()
