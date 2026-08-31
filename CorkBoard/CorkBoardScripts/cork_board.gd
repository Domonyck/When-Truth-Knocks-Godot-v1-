extends Control

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close_corkboard()

func _close_corkboard() -> void:
	# Freeing this scene fires tree_exited, which tells billboard.gd to zoom back out
	queue_free()
