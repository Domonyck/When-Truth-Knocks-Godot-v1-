extends Area3D
 
@export var desktop_scene: PackedScene
 
var is_transitioning := false
 
func interact() -> void:
	if is_transitioning:
		return
 
	if desktop_scene == null:
		print("desktop_scene is not assigned in the Inspector")
		return
 
	var camera = get_tree().get_first_node_in_group("player_camera")
	if camera == null:
		print("no camera found in group 'player_camera'")
		return
 
	is_transitioning = true
 
	camera.set_process(false)
	camera.set_process_input(false)
 
	get_tree().paused = true
 
	var desktop_overlay = desktop_scene.instantiate()
	desktop_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(desktop_overlay)
 
	is_transitioning = false
 
