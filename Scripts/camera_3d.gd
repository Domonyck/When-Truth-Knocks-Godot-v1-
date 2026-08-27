extends Camera3D

@export var max_angle: float = 20.0 # Degrees of rotation
var center_screen_position: Vector2

func _ready() -> void:
	center_screen_position = get_viewport().get_visible_rect().size / 2

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_pos = event.position
		var offset = (mouse_pos - center_screen_position) / center_screen_position
		
		# Apply a slight clamped rotation based on mouse position
		rotation_degrees.y = -offset.x * max_angle
		rotation_degrees.x = -offset.y * max_angle
