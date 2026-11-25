extends Panel

@onready var clock_label: Label = $Label

func _process(_delta: float) -> void:
	var gm := get_tree().get_first_node_in_group("game_manager")
	if gm and clock_label:
		clock_label.text = gm.get_time_string()

func hide_time() -> void:
	visible = false

func show_time() -> void:
	visible = true
