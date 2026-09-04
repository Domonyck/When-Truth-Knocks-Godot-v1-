extends CanvasLayer

@onready var start_button: Button = $Start
@onready var quit_button: Button = $Quit

@export var main_room_path: String = "res://MainRoom.tscn"

func _ready() -> void:
	# Connect button press signals
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(main_room_path)

func _on_quit_pressed() -> void:
	get_tree().quit()
