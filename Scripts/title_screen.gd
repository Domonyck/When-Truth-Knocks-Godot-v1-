extends Node2D

func _ready() -> void:
	# Create a layer that appears above the entire scene
	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 100
	add_child(canvas_layer)

	# Create a fullscreen black overlay
	var fade_overlay := ColorRect.new()
	fade_overlay.color = Color.BLACK
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	canvas_layer.add_child(fade_overlay)

	# Fade from black to transparent
	var tween := create_tween()

	tween.tween_property(
		fade_overlay,
		"modulate:a",
		0.0,
		1.5
	)

	# Remove the overlay after the fade finishes
	tween.tween_callback(canvas_layer.queue_free)
	
