# pause_menu.gd
extends CanvasLayer

@onready var resume_button: Button = $Control/ResumeButton
@onready var quit_button: Button = $Control/QuitButton
@onready var volume: HSlider = $Control/Volume
@onready var brightness: HSlider = $Control/Brightness
@onready var shaders: CheckButton = $Control/Shaders

const SHADER_LAYER_PATH := "SubViewportContainer/SubViewport/Camera3D/CanvasLayer"
const ENV_PATH := "SubViewportContainer/SubViewport/WorldEnvironment"

# Saved here so the values survive opening/closing the menu and scene changes
var brightness_value := 1.0
var shaders_enabled := false   # matches the CanvasLayer's visible = false in MainRoom

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	visible = false

	resume_button.pressed.connect(_on_resume_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Volume: 0..1 linear
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.01
	volume.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")))
	volume.value_changed.connect(_on_volume_changed)

	# Brightness: 1.0 = normal
	brightness.min_value = 0.2
	brightness.max_value = 2.0
	brightness.step = 0.01
	brightness.value = brightness_value
	brightness.value_changed.connect(_on_brightness_changed)

	shaders.button_pressed = shaders_enabled
	shaders.toggled.connect(_on_shaders_toggled)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if get_tree().current_scene and get_tree().current_scene.scene_file_path.get_file() == "TitleScreen.tscn":
			return
		toggle_pause()

func toggle_pause() -> void:
	var opening = !get_tree().paused
	get_tree().paused = opening
	Engine.set_meta("menu_paused", opening)   # <-- add
	visible = opening
	if opening:
		_sync_shader_button()
		_apply_brightness()

# ---------- Volume ----------
func _on_volume_changed(value: float) -> void:
	var idx := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(idx, linear_to_db(value))
	AudioServer.set_bus_mute(idx, value <= 0.001)

# ---------- Brightness ----------
func _on_brightness_changed(value: float) -> void:
	brightness_value = value
	_apply_brightness()

func _apply_brightness() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var we := scene.get_node_or_null(ENV_PATH) as WorldEnvironment
	if we and we.environment:
		we.environment.adjustment_enabled = true
		we.environment.adjustment_brightness = brightness_value

# ---------- Shaders ----------
func _get_shader_layer() -> CanvasLayer:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null(SHADER_LAYER_PATH) as CanvasLayer

func _on_shaders_toggled(pressed: bool) -> void:
	shaders_enabled = pressed
	var layer := _get_shader_layer()
	if layer:
		layer.visible = pressed

# Re-read the real state when the menu opens (in case other scripts changed it)
func _sync_shader_button() -> void:
	var layer := _get_shader_layer()
	shaders.set_pressed_no_signal(layer.visible if layer else false)
	shaders.disabled = layer == null   # greyed out on scenes without the layer

func _on_resume_pressed() -> void:
	toggle_pause()

func _on_quit_pressed() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	Engine.set_meta("menu_paused", false)

	var master_bus_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_bus_idx, false)

	if dominic:
		dominic.set_process(false)
		dominic.reset_state()

	StoryData.new_game()
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm and gm.has_method("reset_state"):
		gm.reset_state()
	for lm in get_tree().get_nodes_in_group("light_manager"):
		if lm.has_method("reset_state"):
			lm.reset_state()
	for t in get_tree().get_nodes_in_group("thunder"):
		if t.has_method("reset_state"):
			t.reset_state()
	for node in get_tree().get_nodes_in_group("desktop_overlay"):
		node.queue_free()

	visible = false
	get_tree().change_scene_to_file("res://TitleScreen.tscn")
