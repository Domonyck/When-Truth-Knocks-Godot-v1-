extends Control # Change this if your root node is a different type (like CanvasLayer)

# This is the signal the Computer2 script is waiting to hear
signal desktop_closed

func _ready() -> void:
	# CRITICAL: This allows the UI to hear your ESC key while the game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	# "ui_cancel" is the default Godot action for the ESC key
	if event.is_action_pressed("ui_cancel"):
		close_ui()

func close_ui() -> void:
	# 1. Stop listening for input so you can't accidentally press ESC twice
	set_process_input(false)
	
	# 2. Unpause the game so the zoom-out animation is allowed to play
	get_tree().paused = false
	
	# 3. Shout out to the Computer2 script: "I am closing! Zoom back out!"
	desktop_closed.emit()
	
	# 4. Delete the UI from the screen
	queue_free()
