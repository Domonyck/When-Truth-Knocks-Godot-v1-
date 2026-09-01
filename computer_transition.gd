extends Area3D

@export var desktop_scene: PackedScene
@export var zoom_target: Node3D 
@export var zoom_duration: float = 1.0 

var is_transitioning := false
var is_desktop_open := false 
var is_powered := true
var original_camera_transform: Transform3D 
var camera: Camera3D
var active_desktop_overlay: Node 

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func interact() -> void:
	# Blocked immediately if no power is supplied by LightPowerManager
	if not is_powered or is_transitioning or is_desktop_open:
		return

	if desktop_scene == null:
		return

	camera = get_tree().get_first_node_in_group("player_camera") as Camera3D
	if camera == null or zoom_target == null:
		return

	is_transitioning = true
	camera.set_process(false)
	camera.set_process_input(false)
	original_camera_transform = camera.global_transform

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD) 
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "global_transform", zoom_target.global_transform, zoom_duration)

	await tween.finished

	# Secondary check: if power cut out while camera was zooming in, abort
	if not is_powered:
		is_transitioning = false
		force_shutdown_desktop()
		return

	get_tree().paused = true
	
	active_desktop_overlay = desktop_scene.instantiate()
	active_desktop_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	active_desktop_overlay.tree_exited.connect(zoom_out_camera)
	
	get_tree().root.add_child(active_desktop_overlay)
	is_desktop_open = true
	is_transitioning = false

func _input(event: InputEvent) -> void:
	if is_desktop_open and not is_transitioning and event.is_action_pressed("ui_cancel"):
		if is_instance_valid(active_desktop_overlay):
			active_desktop_overlay.queue_free()

func force_shutdown_desktop() -> void:
	# Ignore if desktop is already closed or currently transitioning
	if not is_desktop_open and not is_transitioning:
		return

	is_transitioning = true
	is_desktop_open = false

	# 1. Immediately remove active desktop overlay
	if is_instance_valid(active_desktop_overlay):
		if active_desktop_overlay.tree_exited.is_connected(zoom_out_camera):
			active_desktop_overlay.tree_exited.disconnect(zoom_out_camera)
		active_desktop_overlay.queue_free()

	# 2. Unpause the scene tree so physics, tweens, and process functions resume
	get_tree().paused = false

	# 3. Dynamic camera fallback check
	if camera == null:
		camera = get_tree().get_first_node_in_group("player_camera") as Camera3D

	# 4. Animate camera zoom out back to mainroom transform
	if camera != null:
		var tween = create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(camera, "global_transform", original_camera_transform, zoom_duration)
		
		await tween.finished
		
		camera.set_process(true)
		camera.set_process_input(true)

	is_transitioning = false

	if camera != null:
		var tween = create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) 
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(camera, "global_transform", original_camera_transform, zoom_duration)
		
		await tween.finished
		
		camera.set_process(true)
		camera.set_process_input(true)

	is_transitioning = false

func zoom_out_camera() -> void:
	if not is_desktop_open: 
		return 
		
	is_transitioning = true
	is_desktop_open = false
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD) 
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "global_transform", original_camera_transform, zoom_duration)
	
	await tween.finished
	
	get_tree().paused = false
	
	camera.set_process(true)
	camera.set_process_input(true)
	
	is_transitioning = false
