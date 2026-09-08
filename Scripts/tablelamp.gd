extends Area3D

@export var lights: Array[Node3D]
@onready var audio_stream_player: AudioStreamPlayer = $"../LampLight/AudioStreamPlayer"

func interact() -> void:
	for light in lights:
		if light and "visible" in light:
			light.visible = not light.visible
	
	audio_stream_player.play()
