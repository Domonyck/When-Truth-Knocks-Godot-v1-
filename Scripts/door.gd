extends Area3D
@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"
@onready var creak_sound: AudioStreamPlayer = $OpenAndCloseCreakingDoorwav36256

var is_open: bool = false
@export var auto_close_delay: float = 3.0  # seconds before it shuts itself

func interact() -> void:
	if animation_player and not animation_player.is_playing():
		creak_sound.play()
		if is_open:
			_close_door()
		else:
			_open_door()

func _open_door() -> void:
	animation_player.play("door_open")
	is_open = true

	await get_tree().create_timer(auto_close_delay).timeout
	if is_open:
		_close_door()

func _close_door() -> void:
	animation_player.play("door_open", -1, -1.58, true)
	is_open = false
