extends Camera3D

signal transition_triggered

@export var door: Node3D
@export var trigger_point: Node3D # 1st Marker3D: opens the door when reached
@export var trigger_distance: float = 4.0 # Distance in meters where the door starts opening
@export var open_animation_name: String = "open" # Match the animation name in AnimationPlayer
@export var move_duration: float = 6.8
@export var pass_through_distance: float = 2.0

@export_group("Fade & Transition")
@export var fade_in_duration: float = 2.0 # Seconds for the black overlay to fade out at the start of the scene
@export var transition_trigger_point: Marker3D # 2nd Marker3D: switches scene when reached
@export var transition_trigger_distance: float = 0.2 # Tight radius so it triggers right on the marker
@export_file("*.tscn") var next_scene: String = "" # Scene to load when the 2nd marker is reached

var _door_opened: bool = false
var _transition_started: bool = false
var _move_direction: Vector3 = Vector3.ZERO

func _ready() -> void:
	current = true
	_fade_out_black_overlay()

	# Start loading the next scene in the background immediately so there is no freeze on arrival
	if next_scene != "":
		ResourceLoader.load_threaded_request(next_scene)

	if door or transition_trigger_point:
		start_camera_move()

func _fade_out_black_overlay() -> void:
	if fade_in_duration <= 0.0:
		return

	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)

	var fade_rect := ColorRect.new()
	fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(fade_rect)

	var tween := fade_rect.create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, fade_in_duration)
	tween.tween_callback(canvas.queue_free)

func _process(_delta: float) -> void:
	var flat_cam_pos := Vector3(global_position.x, 0.0, global_position.z)

	# 1. Check 1st marker (or door) to open the door
	if not _door_opened and (trigger_point or door):
		var target_node := trigger_point if trigger_point else door
		var flat_target_pos := Vector3(target_node.global_position.x, 0.0, target_node.global_position.z)

		if flat_cam_pos.distance_to(flat_target_pos) <= trigger_distance:
			_open_door()

	# 2. Check 2nd marker to transition to the next scene immediately on contact
	if not _transition_started and transition_trigger_point:
		var flat_transition_pos := Vector3(transition_trigger_point.global_position.x, 0.0, transition_trigger_point.global_position.z)
		var passed_marker := _move_direction != Vector3.ZERO and (flat_cam_pos - flat_transition_pos).dot(_move_direction) >= 0.0

		if passed_marker or flat_cam_pos.distance_to(flat_transition_pos) <= transition_trigger_distance:
			_trigger_transition()

func start_camera_move() -> void:
	var aim_node: Node3D = transition_trigger_point if transition_trigger_point else door
	var aim_level_pos := Vector3(aim_node.global_position.x, global_position.y, aim_node.global_position.z)
	var offset := aim_level_pos - global_position

	if offset.length_squared() < 0.0001:
		push_warning("Camera3D is at the exact same position as its target node.")
		return

	_move_direction = offset.normalized()
	# Aim past the marker so the camera crosses it at full speed without decelerating on top of it
	var end_position := aim_level_pos + (_move_direction * pass_through_distance)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, "global_position", end_position, move_duration)
	tween.tween_callback(func():
		if not _transition_started:
			_trigger_transition()
	)

func _open_door() -> void:
	_door_opened = true

	if door:
		var anim_player := door.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if anim_player:
			if anim_player.has_animation(open_animation_name):
				anim_player.play(open_animation_name)
			else:
				for anim_name in anim_player.get_animation_list():
					if anim_name != "RESET":
						anim_player.play(anim_name)
						break

		var creak_sound := door.get_node_or_null("Area3D/OpenCloseDoor")
		if creak_sound and creak_sound.has_method("play"):
			creak_sound.play()

func _trigger_transition() -> void:
	if _transition_started:
		return
	_transition_started = true

	transition_triggered.emit()

	if next_scene != "":
		var status := ResourceLoader.load_threaded_get_status(next_scene)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var packed_scene := ResourceLoader.load_threaded_get(next_scene) as PackedScene
			get_tree().change_scene_to_packed(packed_scene)
		else:
			get_tree().change_scene_to_file(next_scene)
