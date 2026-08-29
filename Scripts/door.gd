extends Area3D

@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"

func interact() -> void:
	if animation_player and not animation_player.is_playing():
		animation_player.play("door_animation")
