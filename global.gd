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
	print("SceneTree Paused State: ", get_tree().paused)

func _on_resume_pressed() -> void:
	toggle_pause()

func _on_quit_pressed() -> void:
	# 1. Always unpause the SceneTree first so the title screen isn't frozen
	get_tree().paused = false
	
	# 2. Hide the pause overlay CanvasLayer
	visible = false
	
	# 3. Change to your title screen scene path
	get_tree().change_scene_to_file("res://TitleScreen.tscn")
