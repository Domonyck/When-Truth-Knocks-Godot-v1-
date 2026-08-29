extends StaticBody3D

@export var open_mesh: Node3D
@export var closed_mesh: Node3D

var is_open: bool = false

func _on_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle_blinds()

func toggle_blinds():
	is_open = !is_open
	
	open_mesh.visible = is_open
	closed_mesh.visible = !is_open
