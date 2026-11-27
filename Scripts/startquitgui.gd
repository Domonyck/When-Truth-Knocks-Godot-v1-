extends CanvasLayer

@onready var start_button: Button = $Start
@onready var quit_button: Button = $Quit
@onready var ui_music = $FreesoundCommunitySpookyMusicBoxRadioBroadcast32650
@export_file("*.tscn") var next_scene_path: String = "res://opening.tscn"

func _ready() -> void:
	ui_music.play()
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(next_scene_path)

func _on_quit_pressed() -> void:
	get_tree().quit()
