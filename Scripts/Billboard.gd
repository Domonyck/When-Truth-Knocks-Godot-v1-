extends Area3D

@export var billboard_ui_scene: PackedScene
@export var focus_target: Node3D 
@export var focus_duration: float = 1.0 

var is_transitioning := false
var is_billboard_open := false 
var original_camera_transform: Transform3D 
var camera: Camera3D
var active_billboard_overlay: Node 

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func interact() -> void:
	if is_transitioning or is_billboard_open:
		return

	if billboard_ui_scene == null:
		return

	camera = get_tree().get_first_node_in_group("player_camera") as Camera3D
	if camera == null or focus_target == null:
		return

	is_transitioning = true
	camera.set_process(false)
	camera.set_process_input(false)
	original_camera_transform = camera.global_transform

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD) 
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "global_transform", focus_target.global_transform, focus_duration)

	await tween.finished

	get_tree().paused = true
	
	active_billboard_overlay = billboard_ui_scene.instantiate()
	active_billboard_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	
	active_billboard_overlay.tree_exited.connect(unfocus_camera)
	
	get_tree().root.add_child(active_billboard_overlay)
	is_billboard_open = true
	is_transitioning = false

func _input(event: InputEvent) -> void:
	if is_billboard_open and not is_transitioning and event.is_action_pressed("ui_cancel"):
		if is_instance_valid(active_billboard_overlay):
			active_billboard_overlay.queue_free()

func unfocus_camera() -> void:
	if not is_billboard_open: 
		return 
		
	is_transitioning = true
	is_billboard_open = false
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD) 
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "global_transform", original_camera_transform, focus_duration)
	
	await tween.finished
	
	get_tree().paused = false
	
	camera.set_process(true)
	camera.set_process_input(true)
	
	is_transitioning = false
