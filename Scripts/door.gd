extends Area3D

@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"

var is_open: bool = false

func interact() -> void:
	if animation_player and not animation_player.is_playing():
		
		if is_open:
			animation_player.play_backwards("door_open")
		else:
			animation_player.play("door_open")
			
		is_open = not is_open
