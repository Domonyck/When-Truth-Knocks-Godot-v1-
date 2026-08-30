extends Control
 
@onready var window_dialog: Panel = $WindowDialog
@onready var close_button: Button = $WindowDialog/Panel/CloseButton
 
func _ready():
	# Show the window on start (or trigger it via another button)
	window_dialog.show()
	
	# Connect the custom X button to hide the window
	if not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)
 
func _on_close_pressed():
	window_dialog.hide()
 
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close_desktop()
 
func _close_desktop() -> void:
	get_tree().paused = false
 
	var camera = get_tree().get_first_node_in_group("player_camera")
	if camera:
		camera.set_process(true)
		camera.set_process_input(true)
	else:
		print("no camera found in group 'player_camera' on close")
 
	queue_free()
 
