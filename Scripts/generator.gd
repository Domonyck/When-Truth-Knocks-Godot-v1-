extends Node3D

signal repaired

@export var light_manager: Node          # root Node2D with lightmanager.gd
@export var skill_check: Control
@export var clock_nodes: Array[Node]     # GameManager and ClockUI: these keep running while frozen
@export var door: Area3D   # door/Area3D, so the camera can return to its original spot
@export_group("Repair")
@export var total_checks := 3
@export var repair_time := 20.0          # seconds of holding E
@export var trigger_distance := 12.0
@export var miss_penalty := 0.12         # fraction of repair_time lost on a miss
@export var great_bonus := 0.03          # fraction of repair_time gained on a great
@export var start_speed := 2.8
@export var end_speed := 4.2

@export_group("Miss Shake")
@export var shake_strength := 1.5
@export var shake_duration := 0.35
@onready var camera_point: Marker3D = $CameraPoint

var power_out := false
var session_active := false
var progress := 0.0
var check_times: Array[float] = []
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
	progress = 0.0
	next_check = 0
	check_times.clear()
	for i in total_checks:
		var t := (i + randf_range(0.25, 0.85)) / total_checks
		check_times.append(t * repair_time)

func _on_power_restored() -> void:
	if door:
		door.blackout_active = false
	power_out = false
	_end_session()

func _process(delta: float) -> void:
	if not power_out:
		return

	# Before the session: walk to the marker and press E
	if not session_active:
		return

	# During the session: the world is frozen, hold E to repair
	if skill_check.active:
		_hint.hide()
		return

	_hint.text = "Hold E to repair"
	_hint.show()

	if not Input.is_action_pressed("repair"):
		return

	progress += delta

	if next_check < total_checks and progress >= check_times[next_check]:
		var t : float = float(next_check) / max(total_checks - 1, 1)
		skill_check.start_check(lerp(start_speed, end_speed, t), next_check, total_checks)
		return

	if progress >= repair_time and next_check >= total_checks:
		_finish()

func _on_check_finished(result: String) -> void:
	next_check += 1
	match result:
		"great":
			progress = min(progress + great_bonus * repair_time, repair_time)
		"miss":
			progress = max(progress - miss_penalty * repair_time, 0.0)
			_shake_camera()
	if next_check >= total_checks and progress >= repair_time:
		_finish()

func _finish() -> void:
	light_manager.restore_power()   # ends the session and unpauses
	repaired.emit()
	if door and door.has_method("return_from_breaker"):
		door.return_from_breaker()

# ---------- Freeze / resume ----------

func _start_session() -> void:
	session_active = true
	for n in clock_nodes:
		if is_instance_valid(n):
			_saved_modes[n] = n.process_mode
			n.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

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
