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
