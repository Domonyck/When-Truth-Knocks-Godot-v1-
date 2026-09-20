extends CanvasLayer

@onready var start_button: Button = $Start
@onready var quit_button: Button = $Quit
@onready var ui_music = $FreesoundCommunitySpookyMusicBoxRadioBroadcast32650
@export_file("*.tscn") var loading_screen_path: String = "res://loading_screen.tscn"

func _ready() -> void:
	ui_music.play()
	# Connect button press signals
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_start_pressed() -> void:
	# Switch directly to the loading screen scene
	get_tree().change_scene_to_file(loading_screen_path)

func _on_quit_pressed() -> void:
	get_tree().quit()
