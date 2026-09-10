extends Node3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer

@onready var sound_1: AudioStreamPlayer = $FreesoundCommunityWalkingThroughGrass80308
@onready var sound_2: AudioStreamPlayer = $FreesoundCommunityRunningOnGrassWithWetFeet7030
@onready var sound_3: AudioStreamPlayer = $FloraphonicGlassKnock1189096
@onready var sound_4: AudioStreamPlayer = $FloraphonicGlassKnock12189878

var elapsed_time: float = 0.0
var cooldown_timer: float = 0.0

func _ready() -> void:
	_schedule_next_event()

func _process(delta: float) -> void:
	elapsed_time += delta
	cooldown_timer -= delta

	if cooldown_timer <= 0.0:
		if animation_player and not animation_player.is_playing():
			_trigger_random_event()
			_schedule_next_event()

func _schedule_next_event() -> void:
	var total_minutes := elapsed_time / 60.0
	var min_delay: float
	var max_delay: float

	if total_minutes < 3.0:
		# 0-3 mins: ~1-2 triggers total
		min_delay = 60.0
		max_delay = 120.0
	elif total_minutes < 6.0:
		# 3-6 mins: ~6 triggers total
		min_delay = 20.0
		max_delay = 40.0
	else:
		# 6+ mins: ~9 triggers total
		min_delay = 15.0
		max_delay = 25.0

	cooldown_timer = randf_range(min_delay, max_delay)

func _trigger_random_event() -> void:
	# Fixed to include option 4
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
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
	
	if sound_player:
		sound_player.play()
