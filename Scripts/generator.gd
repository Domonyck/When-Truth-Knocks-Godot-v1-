extends Node3D

signal repaired

@export var light_manager: Node          # root Node2D with lightmanager.gd
@export var skill_check: Control
@export var clock_nodes: Array[Node]     # GameManager and ClockUI: these keep running while frozen
@export var door: Area3D   # door/Area3D, so the camera can return to its original spot
@export_group("Repair")
@export var total_checks := 5            # Changed default to 7 checks
@export var trigger_distance := 12.0
@export var start_speed := 2.8
@export var end_speed := 6.0

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
@onready var background: AudioStreamPlayer = $FreesoundCommunityCrickets26444
@onready var sound1: AudioStreamPlayer = $Loswin23DogBarkingInTheDistance520031
@onready var sound2: AudioStreamPlayer = $BarkFartXRsy1he
@onready var sound3: AudioStreamPlayer = $PlanktonAugh
@onready var sound4: AudioStreamPlayer = $Mrstokes302PsstWhisperSfxMrstokes302418603
@onready var sound5: AudioStreamPlayer = $FreesoundCommunityCatsFighting73284
@onready var sound6: AudioStreamPlayer = $FreesoundCommunityRunningInGrass6237
@onready var sound7: AudioStreamPlayer = $TanweramanCarPassBy337871

@export_group("Session Sounds")
@export_range(0.0, 1.0) var sound_chance := 0.6   # chance that a sound plays when a session starts
@export var sound_roll_interval := 2.0            # seconds between chance rolls while no sound is on cooldown
@export var sound_cooldown := 10.0                 # seconds to wait after a sound plays before rolling again

var _all_sounds: Array[AudioStreamPlayer] = []    # sounds 1-7, never changes
var _sound_pool: Array[AudioStreamPlayer] = []    # sounds not played yet; shrinks over the game
var _audio_session_id := 0                        # invalidates stale sound loops when a session ends/restarts

func _ready() -> void:
	# The generator and its canvas layer must keep running while the tree is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("generator")   # so the pause menu can call reset_state()

	_all_sounds = [sound1, sound2, sound3, sound4, sound5, sound6, sound7]
	_sound_pool = _all_sounds.duplicate()
	# Loop the background while the session is running
	background.finished.connect(_on_background_finished)

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
	Notify.show_message("Press Space to Repair", 10)
	session_active = true
	dominic.set_events_paused(true)   # freeze anomaly events during the repair
	next_check = 0
	_start_session_audio()
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
	_stop_all_audio()
	dominic.set_events_paused(false)  # anomaly events resume
	get_tree().paused = false
	for n in _saved_modes:
		if is_instance_valid(n):
			n.process_mode = _saved_modes[n]
	_saved_modes.clear()

# ---------- Reset (called by the pause menu on Quit) ----------

func reset_state() -> void:
	_stop_all_audio()
	_sound_pool = _all_sounds.duplicate()   # every sound can play again
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	if _hint:
		_hint.hide()
	if skill_check and skill_check.active and skill_check.has_method("reset_state"):
		skill_check.reset_state()
	if session_active:
		dominic.set_events_paused(false)
		for n in _saved_modes:
			if is_instance_valid(n):
				n.process_mode = _saved_modes[n]
		_saved_modes.clear()
	session_active = false
	power_out = false
	next_check = 0
	if door:
		door.blackout_active = false

# ---------- Session audio ----------

func _start_session_audio() -> void:
	_audio_session_id += 1
	background.play()
	_sound_loop(_audio_session_id)

# Rolls the chance every sound_roll_interval seconds. After a sound plays, waits
# sound_cooldown seconds before rolling again. Stops when the session ends.
func _sound_loop(id: int) -> void:
	while id == _audio_session_id and session_active and not _sound_pool.is_empty():
		await get_tree().create_timer(sound_roll_interval, true).timeout   # true = ticks while paused
		if id != _audio_session_id or not session_active:
			return
		if randf() <= sound_chance:
			_play_random_sound()
			await get_tree().create_timer(sound_cooldown, true).timeout

func _play_random_sound() -> void:
	if _sound_pool.is_empty():
		return
	var pick: AudioStreamPlayer = _sound_pool.pick_random()
	_sound_pool.erase(pick)   # removed from the pool: won't repeat until every sound has played
	pick.play()
	if _sound_pool.is_empty():
		_sound_pool = _all_sounds.duplicate()   # all played: refill the pool for the next round

func _on_background_finished() -> void:
	if session_active:
		background.play()

func _stop_all_audio() -> void:
	_audio_session_id += 1   # cancels any running _sound_loop
	background.stop()
	for s in _all_sounds:
		s.stop()

func _shake_camera() -> void:
	var cam := get_viewport().get_camera_3d()

	if cam == null:
		print("No active camera found!")
		return

	print("SHAKE ACTIVATED!")

	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()

	_shake_tween = create_tween()
	_shake_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	var original_rotation := cam.rotation
	var steps := 12

	for i in range(steps):
		var falloff := 1.0 - float(i) / steps

		var shake := Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		) * deg_to_rad(shake_strength) * falloff

		_shake_tween.tween_property(
			cam,
			"rotation",
			original_rotation + shake,
			shake_duration / steps
		)

	_shake_tween.tween_property(
		cam,
		"rotation",
		original_rotation,
		0.08
	)
