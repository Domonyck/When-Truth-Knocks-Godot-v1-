extends StaticBody3D

@export var open_mesh: Node3D
@export var closed_mesh: Node3D
@onready var freesound_community_tear_paper_103161: AudioStreamPlayer = $FreesoundCommunityTearPaper103161

var is_open: bool = true

func _ready() -> void:
	open_mesh.visible = is_open
	closed_mesh.visible = !is_open
	
	# Connect to the persistent timer signal on the Autoload
	if dominic:
		dominic.blinds_timer_expired.connect(_on_reopen_timer_timeout)

func _exit_tree() -> void:
	# Disconnect signal when leaving the 3D level scene to prevent memory leaks
	if dominic and dominic.blinds_timer_expired.is_connected(_on_reopen_timer_timeout):
		dominic.blinds_timer_expired.disconnect(_on_reopen_timer_timeout)

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
		# Blinds were closed -> Start persistent 7-second timer on Autoload
		if dominic:
			dominic.start_blinds_timer(7.0)
	else:
		# Blinds manually opened -> Cancel timer on Autoload
		if dominic:
			dominic.stop_blinds_timer()

	freesound_community_tear_paper_103161.play()

func _on_reopen_timer_timeout() -> void:
	# Signal received from Autoload: automatically reopen if closed
	if not is_open:
		is_open = true
		open_mesh.visible = true
		closed_mesh.visible = false
		freesound_community_tear_paper_103161.play()
