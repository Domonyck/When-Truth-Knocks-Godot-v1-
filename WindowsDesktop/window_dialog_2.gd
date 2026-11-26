extends Panel

var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

@onready var title_bar: Panel = $Panel
@onready var close_button: Button = $Panel/CloseButton
@onready var mouse_sound: AudioStreamPlayer = get_node_or_null("../Mouse")
@onready var scroll_container: ScrollContainer = $Panel2/ScrollContainer
@onready var center_container: CenterContainer = $Panel2/ScrollContainer/CenterContainer
@onready var tutorial_image: TextureRect = $Panel2/ScrollContainer/CenterContainer/TextureRect
@export_range(0.2, 1.0, 0.05) var zoom_scale: float = 0.85
func _ready() -> void:
	_fit_image_to_width()
	hide()
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)

func open_window() -> void:
	show()
	move_to_front()
	await get_tree().process_frame
	_fit_image_to_width()


func close_window() -> void:
	hide()
	dragging = false


func _on_close_button_pressed() -> void:
	if mouse_sound:
		mouse_sound.play()
	close_window()


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var mouse_position := get_global_mouse_position()
			var title_rect := Rect2(title_bar.global_position, title_bar.size)

			# Let CloseButton handle its own click without starting a drag
			if close_button and close_button.visible:
				var close_rect := Rect2(close_button.global_position, close_button.size)
				if close_rect.has_point(mouse_position):
					return

			if title_rect.has_point(mouse_position):
				dragging = true
				drag_offset = mouse_position - global_position
				get_viewport().set_input_as_handled()
		else:
			if dragging:
				dragging = false
				get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and dragging:
		global_position = get_global_mouse_position() - drag_offset
		get_viewport().set_input_as_handled()

func _fit_image_to_width() -> void:
	if not tutorial_image or not tutorial_image.texture or not scroll_container:
		return
	var tex_size := tutorial_image.texture.get_size()
	if tex_size.x <= 0.0:
		return

	if center_container:
		center_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	# Leave room for the vertical scrollbar so it doesn't trigger horizontal scroll
	var available_width := maxf(scroll_container.size.x - 18.0, 10.0)
	var zoomed_width := available_width * zoom_scale
	var zoomed_height := tex_size.y * (zoomed_width / tex_size.x)

	tutorial_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tutorial_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tutorial_image.custom_minimum_size = Vector2(zoomed_width, zoomed_height)
