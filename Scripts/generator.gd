extends Node3D

signal repaired

@export var light_manager: Node          # root Node2D with lightmanager.gd
@export var skill_check: Control
@export var clock_nodes: Array[Node]     # GameManager and ClockUI: these keep running while frozen
@export var door: Area3D   # door/Area3D, so the camera can return to its original spot
@export_group("Repair")
@export var total_checks := 7            # Changed default to 7 checks
@export var trigger_distance := 12.0
@export var start_speed := 2.8
@export var end_speed := 7.2

@export_group("Miss Shake")
@export var shake_strength := 1.5
@export var shake_duration := 0.35
@onready var camera_point: Marker3D = $CameraPoint
@onready var click: AudioStreamPlayer = $Clicks
var power_out := false
var session_active := false
var next_check := 0
var _saved_modes := {}
var _shake_tween: Tween
var _hint: Label

func _ready() -> void:
	# The generator and its canvas layer must keep running while the tree is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	skill_check.finished.connect(_on_check_finished)
	light_manager.blackout_started.connect(_on_blackout)
	light_manager.power_restored.connect(_on_power_restored)

	_hint = Label.new()
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.position.y -= 80
	_hint.hide()
	skill_check.get_parent().add_child(_hint)
	if door:
		door.arrived_at_breaker.connect(_on_arrived_at_breaker)
	
	if light_manager.is_blackout:
		_on_blackout()

func _on_arrived_at_breaker() -> void:
	if power_out and not session_active:
		_start_session()
	
func _on_blackout() -> void:
	if door:
		door.blackout_active = true
	power_out = true
	next_check = 0

func _on_power_restored() -> void:
	if door:
		door.blackout_active = false
	power_out = false
	_end_session()

func _process(_delta: float) -> void:
	if not power_out or not session_active:
		return

	# If a skill check is currently active, hide prompt
	if skill_check.active:
		_hint.hide()
		return

	# Prompt the player to start/continue the sequence with a single press
	_hint.text = "Press E to repair"
	_hint.show()

	if Input.is_action_just_pressed("repair") and not skill_check.active:
		_trigger_next_check()

func _trigger_next_check() -> void:
	_hint.hide()
	
	# Calculate progression percentage from 0.0 (stage 1) to 1.0 (stage 7)
	var t : float = float(next_check) / max(total_checks - 1, 1)
	
	# Interpolate speed and pass 't' to skill_check
	var current_speed : int = lerp(start_speed, end_speed, t)
	skill_check.start_check(current_speed, next_check, total_checks, t)

func _on_check_finished(result: String) -> void:
	match result:
		"great", "good":
			next_check += 1
		"miss":
			# Optional: Decide if a miss resets progress or just shakes. 
			# Keeping it simple: a miss just shakes, but you can add penalty logic here if desired.
			_shake_camera()

	if next_check >= total_checks:
		_finish()
	else:
		# Automatically trigger the next check right after finishing the previous one
		_trigger_next_check()

func _finish() -> void:
	light_manager.restore_power()   # ends the session and unpauses
	repaired.emit()
	if door and door.has_method("return_from_breaker"):
		door.return_from_breaker()

# ---------- Freeze / resume ----------

func _start_session() -> void:
	session_active = true
	next_check = 0
	for n in clock_nodes:
		if is_instance_valid(n):
			_saved_modes[n] = n.process_mode
			n.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	# Automatically kick off the first skill check immediately upon arriving
	_trigger_next_check()

func _end_session() -> void:
	_hint.hide()
	if not session_active:
		return
	session_active = false
	get_tree().paused = false
	for n in _saved_modes:
		if is_instance_valid(n):
			n.process_mode = _saved_modes[n]
	_saved_modes.clear()

func _shake_camera() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween()
	var steps := 8
	var from := Vector2(cam.h_offset, cam.v_offset)
	for i in steps:
		var falloff := 1.0 - float(i) / steps
		var to := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_strength * falloff
		_shake_tween.tween_method(func(o: Vector2): cam.h_offset = o.x; cam.v_offset = o.y, from, to, shake_duration / steps)
		from = to
	_shake_tween.tween_method(func(o: Vector2): cam.h_offset = o.x; cam.v_offset = o.y, from, Vector2.ZERO, 0.04)
