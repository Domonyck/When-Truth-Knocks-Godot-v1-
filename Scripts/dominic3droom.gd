extends Node3D

@onready var local_dominic_anim: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	if dominic:
		dominic.set_process(true)
		dominic.room_anim_player = local_dominic_anim
	print("--- ROOM READY: Registering AnimationPlayer ---")
	if local_dominic_anim:
		dominic.room_anim_player = local_dominic_anim
		print("Successfully assigned AnimationPlayer to Autoload!")
	else:
		print("ERROR: Could not find AnimationPlayer node at path!")

func _exit_tree() -> void:
	if dominic.room_anim_player == local_dominic_anim:
		dominic.room_anim_player = null
