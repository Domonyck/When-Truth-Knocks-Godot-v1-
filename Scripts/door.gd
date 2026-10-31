extends Area3D

signal visitor_revealed
signal arrived_at_breaker
@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"
@onready var creak_sound: AudioStreamPlayer = $OpenAndCloseCreakingDoorwav36256
@onready var knocking_on_door_46237: AudioStreamPlayer = $KnockingOnDoor46237

@export var go_to_breaker_button: Button
@export var go_back_button: Button
@export var breaker_marker: Marker3D
@export var auto_close_delay: float = 1.0   # used for the knock event only

@export_group("Camera Travel")
@export var travel_time := 0.25
@export var arc_height := 0.3
@export var breaker_look_target: Marker3D
var at_breaker := false
var is_open := false
var is_animating := false
var has_visitor := false
var traveling := false
var choosing := false          # true while the two buttons are showing
var original_transform: Transform3D
var has_original := false
var _saved_mouse_mode := Input.MOUSE_MODE_VISIBLE
var blackout_active := false   # set by generator.gd
func _ready() -> void:
	_set_buttons_visible(false)
	go_to_breaker_button.pressed.connect(_on_go_to_breaker)
	go_back_button.pressed.connect(_on_go_back)

func trigger_knock() -> void:
	if not is_open:
		has_visitor = true
		knocking_on_door_46237.play()
		print("DEBUG: Knock triggered!")
		
		# If your knock event opens the door automatically, call _open_door(false) here:
		# _open_door(false)

func interact() -> void:
	if is_animating or traveling or choosing or at_breaker:
		return
	if is_open:
		_close_door()
	else:
		_open_door(true)
func open_door() -> void:
	if is_open or is_animating:
		return
	_open_door(false)   # no visitor, not by player -> just opens

func close_door() -> void:
	if not is_open or is_animating:
		return
	_close_door()
	
func _open_door(by_player: bool = false) -> void:
	is_animating = true
	is_open = true
	creak_sound.stream_paused = false
	creak_sound.play()
	animation_player.play("door_open")

	await animation_player.animation_finished
	is_animating = false

	# 1. KNOCK EVENT: Prioritize visitor, no choices shown
	if has_visitor:
		has_visitor = false
		visitor_revealed.emit()
		print("DEBUG: Signal emitted! The witness should spawn now.")
		await get_tree().create_timer(auto_close_delay).timeout
		if is_open and not is_animating:
			_close_door()
			
	# 2. NO-KNOCK EVENT: Wait 1 second before pausing the sound and showing choices
	elif by_player:
		await get_tree().create_timer(1.0).timeout
		
		# Make sure the player hasn't already closed the door during this 1 second wait
		if is_open and not is_animating:
			creak_sound.stream_paused = true
			_show_choices()

func _close_door() -> void:
	is_animating = true
	is_open = false
	
	# If the sound was left paused (e.g. if closed programmatically elsewhere), ensure it unpauses or stops
	creak_sound.stream_paused = false
	
	animation_player.play("door_open", -1, -1.58, true)

	await animation_player.animation_finished
	is_animating = false

# ---------- Choices (no-knock only) ----------

func _show_choices() -> void:
	choosing = true
	_saved_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_buttons_visible(true)
	go_to_breaker_button.visible = blackout_active

func _hide_choices(restore_mouse := true) -> void:
	choosing = false
	_set_buttons_visible(false)
	if restore_mouse:
		Input.mouse_mode = _saved_mouse_mode

func _set_buttons_visible(value: bool) -> void:
	go_to_breaker_button.visible = value
	go_back_button.visible = value

func _on_go_to_breaker() -> void:
	if not blackout_active:
		return
	creak_sound.stream_paused = false
	_hide_choices(false)   # keep the cursor visible

	var cam := get_viewport().get_camera_3d()
	if cam == null or breaker_marker == null:
		Input.mouse_mode = _saved_mouse_mode
		_close_door()
		return
	if not has_original:
		original_transform = cam.global_transform
		has_original = true

	# Camera ends up at the marker, facing the breaker
	var target := breaker_marker.global_transform
	if breaker_look_target:
		target = target.looking_at(breaker_look_target.global_position, Vector3.UP)

	await _travel(cam, target, false, true)   # keep_frozen = true
	at_breaker = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _close_door()
	arrived_at_breaker.emit()

func return_from_breaker() -> void:
	if not at_breaker or traveling:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	at_breaker = false
	has_original = false
	await _travel(cam, original_transform, true)   # re-enables the camera at the end
	Input.mouse_mode = _saved_mouse_mode
	
func _on_go_back() -> void:
	# Resume the paused creak sound right as a choice is picked
	creak_sound.stream_paused = false
	
	_hide_choices()
	var cam := get_viewport().get_camera_3d()
	if cam != null and has_original:
		await _travel(cam, original_transform)
		has_original = false
	_close_door()

# ---------- Arc tween ----------

func _travel(cam: Camera3D, target: Transform3D, while_paused := false, keep_frozen := false) -> void:
	traveling = true
	cam.set_process(false)
	cam.set_physics_process(false)
	cam.set_process_input(false)
	cam.set_process_unhandled_input(false)

	var start_transform := cam.global_transform
	var tween := create_tween().set_parallel(false)
	
	# Tween a progress value from 0.0 to 1.0 over the travel_time duration
	tween.tween_method(func(val: float) -> void:
		# Interpolate position linearly, then add a parabolic arc offset based on arc_height
		var current_pos := start_transform.origin.lerp(target.origin, val)
		current_pos.y += sin(val * PI) * arc_height
		
		# Slerp (Spherical Linear Interpolation) the rotation basis smoothly
		var current_basis := start_transform.basis.slerp(target.basis, val)
		
		cam.global_transform = Transform3D(current_basis, current_pos)
	, 0.0, 1.0, travel_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await tween.finished

	if not keep_frozen:
		cam.set_process(true)
		cam.set_physics_process(true)
		cam.set_process_input(true)
		cam.set_process_unhandled_input(true)
	traveling = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_K:
		trigger_knock()
	elif at_breaker and not traveling and event.is_action_pressed("ui_cancel"):
		return_from_breaker()
