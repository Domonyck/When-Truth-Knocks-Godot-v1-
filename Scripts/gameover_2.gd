extends Node2D
# Attach to the root Node2D of gameover2.tscn

@export_file("*.tscn") var restart_scene := "res://MainRoom.tscn"   # <-- change to your gameplay scene
@export_file("*.tscn") var title_scene := "res://TitleScreen.tscn"

@export var jumpscare_sound: AudioStream   # drag your sound here in the Inspector

@export var fade_in_time := 1.0
@export var newspaper_fade_time := 1.5
@export var you_delay := 4.0
@export var failed_delay := 2.0
@export var buttons_delay := 2.0
@export var element_fade_time := 0.5
@export var jumpscare_duration := 3.0

@onready var vhs_layer_1: CanvasLayer = $CanvasLayer
@onready var vhs_layer_2: CanvasLayer = $CanvasLayer2
@onready var vhs_1: ColorRect = $CanvasLayer/VHS
@onready var vhs_2: ColorRect = $CanvasLayer2/VHS2
@onready var video: VideoStreamPlayer = $VideoStreamPlayer
@onready var newspaper: TextureRect = $Newspaper
@onready var you: TextureRect = $you
@onready var failed: TextureRect = $failed
@onready var restart_button: Button = $restart
@onready var quit_button: Button = $quit
@onready var jumpscare: CanvasLayer = $jumpscare
@onready var jumpscare_vhs: ColorRect = $jumpscare/ColorRect

var _fade_rect: ColorRect
var _jumpscare_player: AudioStreamPlayer
var _sequence_started := false


func _ready() -> void:
	# Everything else in the game is paused; only this scene keeps running.
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Initial state
	newspaper.visible = false
	you.visible = false
	failed.visible = false
	restart_button.visible = false
	quit_button.visible = false
	jumpscare.visible = false
	jumpscare.layer = 10   # always above the VHS layers

	# The video player in the scene is only 40x40, so make it fill the screen
	video.set_anchors_preset(Control.PRESET_FULL_RECT)
	video.expand = true

	_jumpscare_player = AudioStreamPlayer.new()
	_jumpscare_player.stream = jumpscare_sound
	add_child(_jumpscare_player)

	restart_button.pressed.connect(_on_restart_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	video.finished.connect(_on_video_finished)

	# Black overlay that fades out at the start
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 100
	add_child(fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color.BLACK
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(_fade_rect)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)

	if not video.is_playing():
		video.play()

	await _fade_alpha(_fade_rect, 0.0, fade_in_time)
	fade_layer.queue_free()


func _on_video_finished() -> void:
	if _sequence_started:
		return
	_sequence_started = true

	# Hide both VHS layers, their ColorRects, and the video
	vhs_layer_1.visible = false
	vhs_layer_2.visible = false
	vhs_1.visible = false
	vhs_2.visible = false
	video.visible = false

	# --- First pass: newspaper -> you -> JUMPSCARE ---
	await _show_newspaper()
	await _wait(you_delay)
	you.modulate.a = 1.0
	you.visible = true

	# During jumpscare: only jumpscare's VHS is shown; CanvasLayer and CanvasLayer2 stay hidden
	vhs_layer_1.visible = false
	vhs_layer_2.visible = false
	vhs_1.visible = false
	vhs_2.visible = false
	jumpscare_vhs.visible = true
	jumpscare.visible = true
	if _jumpscare_player.stream:
		_jumpscare_player.play()
	await _wait(jumpscare_duration)
	_jumpscare_player.stop()
	jumpscare.visible = false
	jumpscare_vhs.visible = false

	# After jumpscare ends: make CanvasLayer, CanvasLayer2, VHS, and VHS2 visible
	vhs_layer_1.visible = true
	vhs_layer_2.visible = true
	vhs_1.visible = true
	vhs_2.visible = true

	# --- Second pass: newspaper fades in again, then the real ending ---
	you.visible = false
	await _show_newspaper()
	await _wait(you_delay)
	await _reveal(you)

	await _wait(failed_delay)
	await _reveal(failed)

	await _wait(buttons_delay)
	restart_button.visible = true
	quit_button.visible = true
	restart_button.focus_mode = Control.FOCUS_NONE
	restart_button.grab_focus()

# ---------- helpers ----------
func _show_newspaper() -> void:
	newspaper.modulate.a = 0.0
	newspaper.visible = true
	await _fade_alpha(newspaper, 1.0, newspaper_fade_time)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _fade_alpha(node: CanvasItem, target: float, time: float) -> void:
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", target, time)
	await tw.finished


func _reveal(node: CanvasItem) -> void:
	node.modulate.a = 0.0
	node.visible = true
	await _fade_alpha(node, 1.0, element_fade_time)


# ---------- buttons ----------
func _on_restart_pressed() -> void:
	_lock_buttons()
	_reset_everything()
	get_tree().change_scene_to_file(restart_scene)


func _on_quit_pressed() -> void:
	_lock_buttons()
	_reset_everything()
	get_tree().change_scene_to_file(title_scene)


func _lock_buttons() -> void:
	restart_button.disabled = true
	quit_button.disabled = true


# Same reset the pause menu's Quit does
func _reset_everything() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	Engine.set_meta("menu_paused", false)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)

	var dominic = get_node_or_null("/root/dominic")   # autoload, as used in your pause menu
	if dominic:
		dominic.set_process(false)
		if dominic.has_method("reset_state"):
			dominic.reset_state()

	StoryData.new_game()

	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm and gm.has_method("reset_state"):
		gm.reset_state()
	for group in ["light_manager", "generator", "thunder"]:
		for n in get_tree().get_nodes_in_group(group):
			if n.has_method("reset_state"):
				n.reset_state()
	for n in get_tree().get_nodes_in_group("desktop_overlay"):
		n.queue_free()
