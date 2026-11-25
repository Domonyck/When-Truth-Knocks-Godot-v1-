extends CanvasLayer

@export_group("Phase 1 (4+ min)")
@export var phase1_start: float = 240.0
@export var phase1_durations: Array[float] = [2.0, 5.0, 7.0]
@export_range(0.0, 1.0) var phase1_chance: float = 0.15

@export_group("Phase 2 (8+ min)")
@export var phase2_start: float = 480.0
@export var phase2_durations: Array[float] = [5.0, 7.0]
@export_range(0.0, 1.0) var phase2_chance: float = 0.35

@export_group("Timing")
@export var roll_interval: float = 10.0   # seconds between dice rolls
@export var cooldown: float = 20.0        # pause after a glitch ends

var _gm: Node = null
var _playing: bool = false
var _time_left: float = 0.0
var _roll_timer: float = 0.0
var _cooldown_left: float = 0.0

func _ready() -> void:
	visible = false

func _process(delta: float) -> void:
	if Engine.get_meta("menu_paused", false):
		return

	if _gm == null or not is_instance_valid(_gm):
		_gm = get_tree().get_first_node_in_group("game_manager")
		if _gm == null:
			return

	# Before 4 min, after shift end, or after reset_state() -> no glitch
	if _gm.shift_ended or _gm.real_time_passed < phase1_start:
		if _playing:
			_stop_glitch()
		_roll_timer = 0.0
		_cooldown_left = 0.0
		return

	if _playing:
		_time_left -= delta
		if _time_left <= 0.0:
			_stop_glitch()
		return

	if _cooldown_left > 0.0:
		_cooldown_left -= delta
		return

	_roll_timer -= delta
	if _roll_timer <= 0.0:
		_roll_timer = roll_interval
		var in_phase2: bool = _gm.real_time_passed >= phase2_start
		var chance: float = phase2_chance if in_phase2 else phase1_chance
		if randf() < chance:
			var pool: Array[float] = phase2_durations if in_phase2 else phase1_durations
			_start_glitch(pool.pick_random())

func _start_glitch(duration: float) -> void:
	_playing = true
	_time_left = duration
	visible = true
	print("[Glitch] PLAYING for ", duration, "s")

func _stop_glitch() -> void:
	_playing = false
	_cooldown_left = cooldown
	visible = false
