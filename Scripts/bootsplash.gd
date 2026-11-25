
extends Control

@export var load_scene: PackedScene

@export var in_time: float = 0.3
@export var fade_in_time: float = 0.7
@export var pause_time: float = 2.5
@export var fade_out_time: float = 0.7
@export var out_time: float = 0.3

@onready var splash_screen_container: Node = $SplashScreenContainer

var splash_screens: Array[Node] = []


func _ready() -> void:
	if load_scene == null:
		push_error("BootSplash: Load Scene is not assigned!")
		return

	get_screens()
	fade()


func get_screens() -> void:
	splash_screens = splash_screen_container.get_children()

	for screen in splash_screens:
		if screen is CanvasItem:
			screen.modulate.a = 0.0

		if screen is AnimatedSprite2D:
			screen.play()


func fade() -> void:
	for screen in splash_screens:
		if not screen is CanvasItem:
			continue

		var tween = create_tween()

		tween.tween_interval(in_time)
		tween.tween_property(
			screen,
			"modulate:a",
			1.0,
			fade_in_time
		)

		tween.tween_interval(pause_time)

		tween.tween_property(
			screen,
			"modulate:a",
			0.0,
			fade_out_time
		)

		tween.tween_interval(out_time)

		await tween.finished

	transition_to_scene()
	

func transition_to_scene() -> void:
	var tree := get_tree()

	# Create an overlay that survives scene changes.
	var transition_layer := CanvasLayer.new()
	transition_layer.layer = 128
	tree.root.add_child(transition_layer)

	var fade_rect := ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.modulate = Color.WHITE
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	transition_layer.add_child(fade_rect)

	# Start the fade independently of the BootSplash script.
	var tween := transition_layer.create_tween()
	tween.tween_interval(0.5)
	tween.tween_property(
		fade_rect,
		"modulate",
		Color(1, 1, 1, 0),
		3.0
	)
	tween.tween_callback(transition_layer.queue_free)

	# Change scenes after the persistent overlay is ready.
	var error := tree.change_scene_to_packed(load_scene)

	if error != OK:
		push_error("BootSplash: Failed to load title screen.")
		transition_layer.queue_free()
