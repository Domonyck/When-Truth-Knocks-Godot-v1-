extends TextureButton

@onready var mouse_sound: AudioStreamPlayer = $"../Mouse"
@onready var window_dialog_2: Control = $"../WindowDialog2"

func _ready() -> void:
	# Hide on start if you want it closed until clicked
	window_dialog_2.hide()
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	if mouse_sound:
		mouse_sound.play()
	if window_dialog_2:
		window_dialog_2.show()
		window_dialog_2.move_to_front()
