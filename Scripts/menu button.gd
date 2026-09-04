extends Button


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	connect("mouse_entered", mouseEntered)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func mouseEntered() -> void:
	$"../Arrow".position.y = position.y
