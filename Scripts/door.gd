extends Area3D

signal visitor_revealed 

@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"
@onready var creak_sound: AudioStreamPlayer = $OpenAndCloseCreakingDoorwav36256
@onready var knocking_on_door_46237: AudioStreamPlayer = $KnockingOnDoor46237

var is_open: bool = false
var is_animating: bool = false
var has_visitor: bool = false 
@export var auto_close_delay: float = 1.0

func trigger_knock() -> void:
	if not is_open:
		has_visitor = true
		knocking_on_door_46237.play()
		print("DEBUG: Knock triggered!")

func interact() -> void:
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

	if has_visitor:
		has_visitor = false 
		visitor_revealed.emit() 
		print("DEBUG: Signal emitted! The witness should spawn now.")

	await get_tree().create_timer(auto_close_delay).timeout

	if is_open and not is_animating:
		_close_door()

func _close_door() -> void:
	is_animating = true
	is_open = false
	animation_player.play("door_open", -1, -1.58, true) 
	
	await animation_player.animation_finished
	is_animating = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_K:
		trigger_knock()
