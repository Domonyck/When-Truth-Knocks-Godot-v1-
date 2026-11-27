extends Node3D

@export var camera: Camera3D
@export var trigger_point: Node3D # Optional: leave empty to measure distance from the door
@export var trigger_distance: float = 4.0
@export var open_animation_name: String = "open"

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var creak_sound = $Area3D/OpenAndCloseCreakingDoorwav36256

var _is_open: bool = false

func _ready() -> void:
	# Automatically find the active Camera3D if left empty in the Inspector
	if not camera:
		camera = get_viewport().get_camera_3d()

func _process(_delta: float) -> void:
	if _is_open or not camera:
		return

	var target := trigger_point if trigger_point else self
	var flat_cam_pos := Vector3(camera.global_position.x, 0.0, camera.global_position.z)
	var flat_target_pos := Vector3(target.global_position.x, 0.0, target.global_position.z)

	if flat_cam_pos.distance_to(flat_target_pos) <= trigger_distance:
		open_door()

func open_door() -> void:
	if _is_open:
		return
	_is_open = true

	if anim_player:
		if anim_player.has_animation(open_animation_name):
			anim_player.play(open_animation_name)
		else:
			# Fallback: play the first non-RESET animation if the name differs
			for anim_name in anim_player.get_animation_list():
				if anim_name != "RESET":
					anim_player.play(anim_name)
					break

	if creak_sound and creak_sound.has_method("play"):
		creak_sound.play()
