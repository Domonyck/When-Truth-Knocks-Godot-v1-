extends StaticBody3D

@export var open_mesh: Node3D
@export var closed_mesh: Node3D

var is_open: bool = true
var reopen_timer: Timer

func _ready() -> void:
	# Create a dedicated Timer node script-side to prevent silent failures
	reopen_timer = Timer.new()
	reopen_timer.one_shot = true
	reopen_timer.wait_time = 7.0
	reopen_timer.timeout.connect(_on_reopen_timer_timeout)
	add_child(reopen_timer)
	open_mesh.visible = is_open
	closed_mesh.visible = !is_open
	
func interact() -> void:
	toggle_blinds()

func _on_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		toggle_blinds()

func toggle_blinds() -> void:
	is_open = !is_open
	
	open_mesh.visible = is_open
	closed_mesh.visible = !is_open
	
	if not is_open:
		# Blinds were closed -> start/restart the 7-second timer
		reopen_timer.start(7.0)
	else:
		# Blinds were manually opened -> stop timer if running
		reopen_timer.stop()

func _on_reopen_timer_timeout() -> void:
	# Timer finished: reopen the blinds if still closed
	if not is_open:
		toggle_blinds()
