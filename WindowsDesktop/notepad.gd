extends TextureButton
@onready var monkeytype_window: Control = $"../Notepad2"
@onready var mouse: AudioStreamPlayer = $Mouse # adjust path to match your scene

func _ready() -> void:
	monkeytype_window.hide()
	gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		mouse.play()
		if event.double_click:
			_open_window()

func _open_window() -> void:
	monkeytype_window.start_manuscript("intro")
	monkeytype_window.move_to_front()
