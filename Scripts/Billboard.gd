extends Area3D
# Same interact -> zoom-in -> open UI -> zoom-out flow as computer_transition.gd,
# just pointed at the bulletin board puzzle instead of a desktop scene.
#
# SETUP:
#   - focus_target: a Marker3D placed where the camera should end up,
#     framing the bulletin board.
#   - bulletinboard_scene: assign BulletinBoardUI.tscn here in the Inspector.

@export var bulletinboard_scene: PackedScene
@export var focus_target: Node3D
@export var focus_duration: float = 1.0

var is_transitioning := false
var is_billboard_open := false
var original_camera_transform: Transform3D
var camera: Camera3D
var active_bulletinboard_overlay: Node  # kept as a reference; closing happens from inside the overlay itself

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func interact() -> void:
	if is_transitioning or is_billboard_open:
		return

	if bulletinboard_scene == null:
		return

	camera = get_tree().get_first_node_in_group("player_camera") as Camera3D
	if camera == null or focus_target == null:
		return

	is_transitioning = true
	camera.set_process(false)
	camera.set_process_input(false)

	# Optional: Disable player character movement here (e.g., player.set_physics_process(false))

	original_camera_transform = camera.global_transform

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "global_transform", focus_target.global_transform, focus_duration)

	await tween.finished

	get_tree().paused = true

	active_bulletinboard_overlay = bulletinboard_scene.instantiate()
	active_bulletinboard_overlay.add_to_group("bulletinboard_overlay")
	active_bulletinboard_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	active_bulletinboard_overlay.tree_exited.connect(zoom_out_camera)

	get_tree().root.add_child(active_bulletinboard_overlay)
	is_billboard_open = true
	is_transitioning = false

## Called automatically when the BulletinBoardUI overlay leaves the tree —
## either because the player pressed Esc inside it (see Bulletin_Board.gd's
## own _input, which is what actually catches Esc since that overlay is
## set to PROCESS_MODE_ALWAYS and keeps running while this node's own
## _input is paused out) or because the puzzle auto-closed after solving.
func zoom_out_camera() -> void:
	if not is_billboard_open:
		return

	is_transitioning = true
	is_billboard_open = false

	get_tree().paused = false

	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "global_transform", original_camera_transform, focus_duration)

	await tween.finished

	camera.set_process(true)
	camera.set_process_input(true)

	# Optional: Re-enable player movement here (e.g., player.set_physics_process(true))

	is_transitioning = false
