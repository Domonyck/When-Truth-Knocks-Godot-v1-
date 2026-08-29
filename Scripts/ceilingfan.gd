extends Area3D

@export var lights: Array[Node3D] # Drag your specific light nodes here in the Inspector

func interact() -> void:
	for light in lights:
		if light and "visible" in light:
			light.visible = not light.visible
