extends Node

@onready var sound_1: AudioStreamPlayer = $FreesoundCommunityWalkingThroughGrass80308
@onready var sound_2: AudioStreamPlayer = $FreesoundCommunityRunningOnGrassWithWetFeet7030
@onready var sound_3: AudioStreamPlayer = $FloraphonicGlassKnock1189096
@onready var sound_4: AudioStreamPlayer = $FloraphonicGlassKnock12189878

var elapsed_time: float = 0.0
var cooldown_timer: float = 0.0

# Variable to hold the local 3D animation player when in a 3D level
var room_anim_player: AnimationPlayer = null 

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_schedule_next_event()
# anomaly_4.gd (dominic autoload)

# Add this function to clear all active state
func stop_all_audio() -> void:
	if sound_1 and sound_1.playing: sound_1.stop()
	if sound_2 and sound_2.playing: sound_2.stop()
	if sound_3 and sound_3.playing: sound_3.stop()
	if sound_4 and sound_4.playing: sound_4.stop()

# Fully reset state when returning to the title screen
func reset_state() -> void:
	stop_all_audio()
	
	elapsed_time = 0.0
	cooldown_timer = 0.0
	room_anim_player = null
	
	_schedule_next_event()
	
func _process(delta: float) -> void:
	if get_tree().current_scene and get_tree().current_scene.scene_file_path.get_file() == "TitleScreen.tscn":
			return
	elapsed_time += delta
	cooldown_timer -= delta

	if cooldown_timer <= 0.0:
		_trigger_random_event()
		_schedule_next_event()

func _schedule_next_event() -> void:
	var total_minutes := elapsed_time / 60.0
	var min_delay: float
	var max_delay: float

	if total_minutes < 3.0:
		min_delay = 60.0
		max_delay = 80.0
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
