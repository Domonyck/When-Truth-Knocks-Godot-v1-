
extends Control

@onready var window_dialog: Panel = $WindowDialog
@onready var close_button: Button = $WindowDialog/Panel/CloseButton
@onready var mouse: AudioStreamPlayer = $Mouse
@onready var clock_label_two = $Panel/Time/Label
@onready var start_button: Button = $Panel/Start

func _ready() -> void:
	GameManager.register_clock_2(clock_label_two)

	# Show the Welcome window automatically only once.
	if not GameManager.welcome_already_shown:
		window_dialog.show()
		GameManager.welcome_already_shown = true
	else:
		window_dialog.hide()

	# Connect Start button.
	if not start_button.pressed.is_connected(_on_start_pressed):
		start_button.pressed.connect(_on_start_pressed)

	# Connect Close button.
	if not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)


func _on_close_pressed() -> void:
	mouse.play()
	window_dialog.hide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close_desktop()
		
func _on_start_pressed() -> void:
	mouse.play()
	window_dialog.show()

func _close_desktop() -> void:
	get_tree().paused = false

	var camera = get_tree().get_first_node_in_group("player_camera")

	if camera:
		camera.set_process(true)
		camera.set_process_input(true)
	else:
		print("no camera found in group 'player_camera' on close")

	get_tree().call_group("game_manager", "show_time")

	queue_free()
