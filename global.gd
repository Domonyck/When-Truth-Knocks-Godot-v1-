# pause_menu.gd
extends CanvasLayer

@onready var resume_button: Button = $Control/ResumeButton
@onready var quit_button: Button = $Control/QuitButton

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	visible = false
	
	resume_button.pressed.connect(_on_resume_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		# Prevent pausing if we are on the title screen
		if get_tree().current_scene and get_tree().current_scene.scene_file_path.get_file() == "TitleScreen.tscn":
			return
			
		toggle_pause()

func toggle_pause() -> void:
	var opening = !get_tree().paused
	get_tree().paused = opening
	visible = opening
	var master_bus_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_bus_idx, opening)
	print("SceneTree Paused State: ", get_tree().paused)

func _on_resume_pressed() -> void:
	toggle_pause()

func _on_quit_pressed() -> void:
	# 1. Reset time scale and unpause the tree
	Engine.time_scale = 1.0
	get_tree().paused = false
	
	# 2. Make sure master audio bus is unmuted
	var master_bus_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_bus_idx, false)
	
	# 3. Explicitly reset and stop all audio on the dominic autoload
	if dominic:
			dominic.set_process(false) # Disable _process loop
			dominic.reset_state()

	# 4. Clean up active overlays if any exist
	for node in get_tree().get_nodes_in_group("desktop_overlay"):
		node.queue_free()

	# 5. Hide the pause menu and switch to TitleScreen
	visible = false
	get_tree().change_scene_to_file("res://TitleScreen.tscn")
