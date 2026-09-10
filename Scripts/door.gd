extends Area3D

@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"
@onready var creak_sound: AudioStreamPlayer = $OpenAndCloseCreakingDoorwav36256

var is_open: bool = false
var is_animating: bool = false
@export var auto_close_delay: float = 1.0 # Shorter default wait time

func interact() -> void:
	# Ignore input only if an animation is actively playing
	if is_animating:
		return

	if is_open:
		_close_door()
	else:
		_open_door()

func _open_door() -> void:
	is_animating = true
	is_open = true
	creak_sound.play()
	animation_player.play("door_open")
	await animation_player.animation_finished
	is_animating = false

	# Wait for auto-close delay
	await get_tree().create_timer(auto_close_delay).timeout
	
	# Only auto-close if the door was not manually closed early
	if is_open and not is_animating:
		_close_door()

func _close_door() -> void:
	is_animating = true
	is_open = false
	animation_player.play("door_open", -1, -1.58, true)
	await animation_player.animation_finished
	is_animating = false
