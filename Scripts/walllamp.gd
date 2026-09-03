extends Area3D

@export var lights: Array[Node3D]
@onready var audio_player: AudioStreamPlayer3D = get_node_or_null("AudioStreamPlayer3D")

func _ready() -> void:
	input_ray_pickable = true

# Use the built-in signal handler name directly
func _on_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("CLICK DETECTED!") # Check if this shows in the Output tab
		
		if has_node("AudioStreamPlayer3D"):
			$AudioStreamPlayer3D.play()
		else:
			print("AudioStreamPlayer3D missing as child!")

		interact()

func interact() -> void:
	print("Toggling lights...")
	for light in lights:
		if is_instance_valid(light) and "visible" in light:
			light.visible = not light.visible
