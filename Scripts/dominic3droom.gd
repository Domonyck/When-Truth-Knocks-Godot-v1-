extends Node3D

# Reference the AnimationPlayer attached to the local 3D Dominic model
@onready var local_dominic_anim: AnimationPlayer = $AnimationPlayer

# Inside dominic3droom.gd
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
	# Clean up reference when leaving mainroom so it doesn't leak
	if dominic.room_anim_player == local_dominic_anim:
		dominic.room_anim_player = null
