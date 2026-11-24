extends Node

@onready var sound_1: AudioStreamPlayer = $FreesoundCommunityWalkingThroughGrass80308
@onready var sound_2: AudioStreamPlayer = $FreesoundCommunityRunningOnGrassWithWetFeet7030
@onready var sound_3: AudioStreamPlayer = $FloraphonicGlassKnock1189096
@onready var sound_4: AudioStreamPlayer = $FloraphonicGlassKnock12189878
@onready var wrong: AudioStreamPlayer = $WrongDecision
@onready var life_lost_1: AudioStreamPlayer = $FastBanging
@onready var life_lost_2: AudioStreamPlayer = $MediumFastBanging
@onready var life_lost_3: AudioStreamPlayer = $SuperFastBanging
var elapsed_time: float = 0.0
var cooldown_timer: float = 0.0

# Variable to hold the local 3D animation player when in a 3D level
var room_anim_player: AnimationPlayer = null
signal blinds_timer_expired

# Emitted when the hidden lives run out. Hook your game-over screen to this if you prefer signals.
signal lives_exhausted

# ------------------------------------------------------------------
# HIDDEN LIVES / "SECURE THE ROOM" CHALLENGE
# ------------------------------------------------------------------
const MAX_LIVES: int = 4

# Optional: scene to load when the lives run out (e.g. "res://GameOver.tscn").
# Leave empty to only emit the lives_exhausted signal.
const GAME_OVER_SCENE: String = ""

const CHALLENGE_WINDOW: float = 12.5
# Seconds the warning stays on screen before game over kicks in.
const GAME_OVER_DELAY: float = 3.0

# static_body_3d.gd automatically re-opens the blinds 7 seconds after they are closed.
# true  = blinds count as secured if the player closed them at any point during the window
# false = blinds must be closed at the exact moment the time runs out
const BLINDS_COUNT_IF_CLOSED_DURING_WINDOW: bool = true

# Scripts we look for in the room (matched by file name, so node names/paths don't matter).
const SCRIPT_TABLE_LAMP: String = "tablelamp.gd"
const SCRIPT_WALL_LAMP: String = "walllamp.gd"
const SCRIPT_CEILING_FAN: String = "ceilingfan.gd"
const SCRIPT_BLINDS: String = "static_body_3d.gd"

var _lives: int = MAX_LIVES
var _challenge_active: bool = false
var _challenge_timer: float = 0.0
var _game_over: bool = false
var _blinds_closed_seen: bool = false
var _node_cache: Dictionary = {}

# While true, nothing in this script advances: no new events, no event cooldown,
# no challenge countdown. The generator minigame turns this on and off.
var events_paused: bool = false

var blinds_timer: Timer
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_schedule_next_event()
	blinds_timer = Timer.new()
	blinds_timer.one_shot = true
	blinds_timer.process_mode = Node.PROCESS_MODE_ALWAYS # Ticks during 2D overlays
	blinds_timer.timeout.connect(_on_blinds_timer_timeout)
	add_child(blinds_timer)
# anomaly_4.gd (dominic autoload)

# Add this function to clear all active state
func stop_all_audio() -> void:
	if sound_1 and sound_1.playing: sound_1.stop()
	if sound_2 and sound_2.playing: sound_2.stop()
	if sound_3 and sound_3.playing: sound_3.stop()
	if sound_4 and sound_4.playing: sound_4.stop()
	if wrong and wrong.playing: wrong.stop()
	if life_lost_1 and life_lost_1.playing: life_lost_1.stop()
	if life_lost_2 and life_lost_2.playing: life_lost_2.stop()
	if life_lost_3 and life_lost_3.playing: life_lost_3.stop()

func start_blinds_timer(duration: float = 7.0) -> void:
	blinds_timer.start(duration)

func stop_blinds_timer() -> void:
	blinds_timer.stop()

func _on_blinds_timer_timeout() -> void:
	blinds_timer_expired.emit()

# Called by generator.gd: freeze all anomaly activity during the repair minigame.
# Timers resume exactly where they left off when it ends.
func set_events_paused(paused: bool) -> void:
	events_paused = paused
	if paused:
		stop_all_audio()

# Fully reset state when returning to the title screen
func reset_state() -> void:
	events_paused = false
	stop_all_audio()
	if blinds_timer:
		blinds_timer.stop()
	elapsed_time = 0.0
	cooldown_timer = 0.0
	room_anim_player = null

	# Reset the hidden lives / challenge
	_lives = MAX_LIVES
	_challenge_active = false
	_challenge_timer = 0.0
	_blinds_closed_seen = false
	_game_over = false
	_node_cache.clear()

	_schedule_next_event()

func _process(delta: float) -> void:
	var menu_paused: bool = Engine.get_meta("menu_paused", false)
	if blinds_timer:
		blinds_timer.paused = menu_paused
	if menu_paused:
		return
	if get_tree().current_scene and get_tree().current_scene.scene_file_path.get_file() == "TitleScreen.tscn":
		return
	if _game_over or events_paused:
		return
	elapsed_time += delta
	cooldown_timer -= delta

	if cooldown_timer <= 0.0:
		_trigger_random_event()
		_schedule_next_event()

	_update_challenge(delta)

func _schedule_next_event() -> void:
	var total_minutes := elapsed_time / 60.0
	var min_delay: float
	var max_delay: float

	if total_minutes < 3.0:
		min_delay = 30.0
		max_delay = 60.0
	elif total_minutes < 6.0:
		min_delay = 20.0
		max_delay = 40.0
	else:
		min_delay = 15.0
		max_delay = 35.0

	cooldown_timer = randf_range(min_delay, max_delay)

func _trigger_random_event() -> void:
	var roll := randi_range(1, 4)

	match roll:
		1:
			_play_event("normal_walk", sound_1)
		2:
			_play_event("fast_walk", sound_2)
		3:
			_play_event("normal_tap", sound_3)
		4:
			_play_event("fast_tap", sound_4)

	# Every event starts the "secure the room" countdown
	_begin_challenge()

func _play_event(anim_name: String, sound_player: AudioStreamPlayer) -> void:
	if sound_player:
		if sound_player.stream != null:
			print("PLAYING AUDIO: ", sound_player.name)
			sound_player.play()
		else:
			print_debug("ERROR: Sound player ", sound_player.name, " has no AudioStream assigned!")
	else:
		print_debug("ERROR: sound_player reference is null!")

	if room_anim_player:
		# Check available animations in the console
		print("Available animations: ", room_anim_player.get_animation_list())

		if room_anim_player.has_animation(anim_name):
			room_anim_player.play(anim_name)
		else:
			print_debug("Animation '", anim_name, "' not found on AnimationPlayer!")


# ==================================================================
# HIDDEN LIVES / CHALLENGE LOGIC
# ==================================================================

func _get_response_window() -> float:
	return CHALLENGE_WINDOW

func _begin_challenge() -> void:
	# If a challenge is already running, let it finish instead of stacking a second one
	if _challenge_active or _game_over:
		return
	_challenge_active = true
	_blinds_closed_seen = false
	_challenge_timer = _get_response_window()
	print("CHALLENGE STARTED: ", _challenge_timer, "s to secure the room (lives hidden: ", _lives, ")")

func _update_challenge(delta: float) -> void:
	if not _challenge_active:
		return
	_challenge_timer -= delta
	
	if BLINDS_COUNT_IF_CLOSED_DURING_WINDOW and not _blinds_closed_seen:
		var blinds_node := _get_room_node(SCRIPT_BLINDS)
		if blinds_node and _blinds_are_closed(blinds_node):
			_blinds_closed_seen = true
	
	if _challenge_timer <= 0.0:
		_challenge_active = false
		_resolve_challenge()

# Time is up: check the room, take a life if anything is left unsecured
# Time is up: check the room, take a life if anything is left unsecured
func _resolve_challenge() -> void:
	var missing: Array[String] = _get_missing_requirements()
	if missing.is_empty():
		print("CHALLENGE PASSED. Lives left: ", _lives)
		return

	_lives -= 1
	print("CHALLENGE FAILED (", ", ".join(missing), "). Lives left: ", _lives)

	if _lives > 0:
		var life_lost_index := MAX_LIVES - _lives
		_play_life_lost_audio(life_lost_index)

	Notify.show_message(_build_warning(missing))

	if _lives <= 0:
		_trigger_game_over()

func _play_life_lost_audio(loss_number: int) -> void:
	var player: AudioStreamPlayer = null
	match loss_number:
		1:
			player = life_lost_1
		2:
			player = life_lost_2
		3:
			player = life_lost_3
		_:
			return

	if player == null:
		push_warning("Anomaly: life lost audio player #%d is null." % loss_number)
		return
	if player.stream == null:
		push_warning("Anomaly: '%s' has no AudioStream assigned." % player.name)
		return
	player.play()

# Returns the keys of everything the player failed to secure:
# "table_lamp", "wall_lamp", "ceiling_fan", "blinds", "door"
func _get_missing_requirements() -> Array[String]:
	var missing: Array[String] = []

	var table_lamp := _get_room_node(SCRIPT_TABLE_LAMP)
	if table_lamp and not _lights_are_off(table_lamp):
		missing.append("table_lamp")

	var wall_lamp := _get_room_node(SCRIPT_WALL_LAMP)
	if wall_lamp and not _lights_are_off(wall_lamp):
		missing.append("wall_lamp")

	var fan := _get_room_node(SCRIPT_CEILING_FAN)
	if fan and not _lights_are_off(fan):
		missing.append("ceiling_fan")

	var blinds := _get_room_node(SCRIPT_BLINDS)
	var blinds_ok: bool = _blinds_closed_seen if BLINDS_COUNT_IF_CLOSED_DURING_WINDOW else (blinds == null or _blinds_are_closed(blinds))
	if blinds and not blinds_ok:
		missing.append("blinds")

	if not _door_is_locked():
		missing.append("door")

	return missing

func _build_warning(missing: Array[String]) -> String:
	var messages := {
		"table_lamp": "The table lamp is still on...",
		"wall_lamp": "The wall lamp is still on...",
		"ceiling_fan": "The ceiling light is still on...",
		"blinds": "The blinds are still open... something is watching.",
		"door": "The door isn't locked... it's not safe.",
	}
	var lines: Array[String] = []
	for key in missing:
		lines.append(messages.get(key, "Something is not secured."))
	return "\n".join(lines)

func _trigger_game_over() -> void:
	_game_over = true
	_challenge_active = false
	stop_blinds_timer()
	# Let the player read the last warning before everything ends
	await get_tree().create_timer(GAME_OVER_DELAY).timeout
	if not _game_over:
		return # reset_state() was called while waiting
	stop_all_audio()
	print("ALL LIVES LOST - GAME OVER")
	lives_exhausted.emit()
	if GAME_OVER_SCENE != "":
		get_tree().change_scene_to_file(GAME_OVER_SCENE)

# ------------------------------------------------------------------
# Room state helpers
# ------------------------------------------------------------------

# Finds (and caches) the node in the current scene that uses the given script file.
# Returns null if it doesn't exist (e.g. a 2D level), which simply skips that requirement.
func _get_room_node(script_file: String) -> Node:
	var cached = _node_cache.get(script_file)
	if cached != null and is_instance_valid(cached) and cached.is_inside_tree():
		return cached
	_node_cache.erase(script_file)

	var root := get_tree().current_scene
	if root == null:
		return null
	var found := _find_node_by_script(root, script_file)
	if found:
		_node_cache[script_file] = found
	return found

func _find_node_by_script(node: Node, script_file: String) -> Node:
	var s: Script = node.get_script()
	if s and s.resource_path.get_file() == script_file:
		return node
	for child in node.get_children():
		var found := _find_node_by_script(child, script_file)
		if found:
			return found
	return null

# The lamp / wall lamp / fan scripts all export a `lights` array, so we read the real
# light state instead of depending on each script's internal variables.
func _lights_are_off(node: Node) -> bool:
	if not ("lights" in node):
		push_warning("Anomaly: %s has no 'lights' array, treating it as off." % node.name)
		return true
	for l in node.get("lights"):
		if l == null or not (l is Node3D):
			continue
		var lit: bool = l.is_visible_in_tree()
		if "light_energy" in l and l.light_energy <= 0.0:
			lit = false
		if lit:
			return false
	return true

# static_body_3d.gd exports open_mesh / closed_mesh; blinds are closed when the closed mesh is showing.
func _blinds_are_closed(node: Node) -> bool:
	var closed_mesh = node.get("closed_mesh")
	if closed_mesh is Node3D:
		return closed_mesh.visible
	var open_mesh = node.get("open_mesh")
	if open_mesh is Node3D:
		return not open_mesh.visible
	push_warning("Anomaly: blinds script has no open_mesh/closed_mesh, treating as closed.")
	return true

# The lock state lives on the player camera (camera_3d.gd -> is_door_locked).
# The camera adds itself to the "player_camera" group. No camera (e.g. a 2D level) = skipped.
func _door_is_locked() -> bool:
	var cam := get_tree().get_first_node_in_group("player_camera")
	if cam == null or not ("is_door_locked" in cam):
		return true
	return bool(cam.get("is_door_locked"))
