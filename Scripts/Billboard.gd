extends Area3D

@export var focus_target: Node3D 
@export var focus_duration: float = 1.0 

var is_transitioning := false
var is_billboard_open := false 
var original_camera_transform: Transform3D 
var camera: Camera3D

func interact() -> void:
	if is_transitioning or is_billboard_open:
		return

	camera = get_tree().get_first_node_in_group("player_camera") as Camera3D
	if camera == null or focus_target == null:
		return

	is_transitioning = true
	camera.set_process(false)
	camera.set_process_input(false)
	
	# Optional: Disable player character movement here (e.g., player.set_physics_process(false))
	
	original_camera_transform = camera.global_transform

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD) 
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "global_transform", focus_target.global_transform, focus_duration)

	await tween.finished

	# REMOVED: get_tree().paused = true
	is_billboard_open = true
	is_transitioning = false

func _input(event: InputEvent) -> void:
	if is_billboard_open and not is_transitioning and event.is_action_pressed("ui_cancel"):
		unfocus_camera()

func unfocus_camera() -> void:
	if not is_billboard_open: 
		return 
		
	is_transitioning = true
	is_billboard_open = false
	
	# REMOVED: get_tree().paused = false
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD) 
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "global_transform", original_camera_transform, focus_duration)
	
	await tween.finished
	
	camera.set_process(true)
	camera.set_process_input(true)
	
	# Optional: Re-enable player movement here (e.g., player.set_physics_process(true))
	
	is_transitioning = false
