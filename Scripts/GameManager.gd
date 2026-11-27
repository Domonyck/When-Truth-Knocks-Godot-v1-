extends Node

@onready var door: Area3D = get_node_or_null("../SubViewportContainer/SubViewport/door/Area3D")
@onready var witness_target: Marker3D = get_node_or_null("../WitnessTarget")
@onready var wrong: AudioStreamPlayer = get_node_or_null("../WrongDecision")
@onready var jumpscare: CanvasLayer = get_node_or_null("../Jumpscare")
@onready var jumpscare_audio: AudioStreamPlayer = get_node_or_null("../Jumpscare/Fnaf4NightmareJumpscareSoundEffect")
@export var dialogue_ui: CanvasLayer 
@export var name_label: RichTextLabel 
@export var dialogue_label: RichTextLabel 
@export var Accept: Button
@export var Decline: Button
@export var fade_in_duration: float = 1.5
@export var characters_parent: Node3D
@export_group("Maya Poster Focus")
@export var wanted_poster_texture: Texture2D

@onready var poster_focus_layer: CanvasLayer = get_node_or_null("PosterFocusLayer")
@onready var poster_blur_rect: ColorRect = get_node_or_null("PosterFocusLayer/BackgroundBlur")
@onready var wanted_poster_rect: TextureRect = get_node_or_null("PosterFocusLayer/WantedPoster")

var poster_pause_active: bool = false

# --- TIME MANAGEMENT VARIABLES ---
@export_group("Time Management")
@export var clock_label: Label
var real_time_passed: float = 0.0
const REAL_SECONDS_PER_GAME_HOUR: float = 120.0 # 120 seconds = 2 real minutes
var shift_ended: bool = false
# --- RANDOM JUMPSCARE ---
@export_group("Jumpscare")
@export var jumpscare_start_time: float = 480.0   # 8 real minutes of shift time
@export var jumpscare_roll_interval: float = 10.0 # how often it rolls the dice after 8 min
@export_range(0.0, 1.0) var jumpscare_chance: float = 0.15 # chance per roll
@export var jumpscare_duration: float = 2.0       # visible + audio length
@export var jumpscare_cooldown: float = 180.0     # seconds after a jumpscare before it can be rolled again
var jumpscare_pending: bool = false   # chance succeeded, waiting for player to leave PC/board
var _jumpscare_cooldown_left: float = 0.0
var jumpscare_playing: bool = false
var _jumpscare_roll_timer: float = 0.0
# ---------------------------------
@export_group("Witness Spawning")
@export var witness_interval: float = 60.0      # base time between witnesses
@export var wrong_decision_penalty: float = 20.0 # extra delay for a wrong choice
var next_witness_timer: float = 60.0

# --- OPENING MONOLOGUE ---
@export_group("Intro Monologue")
@export var play_intro: bool = true
@export var intro_start_delay: float = 1.0   # wait for the scene/fade to settle before the box appears
@export var intro_lines: Array[String] = [
	"A crack of thunder splits the sky, and the whole room shudders with it. My heart is still hammering...",
	"Wait... where was I? What was I doing? The rain, the flickering lights, that thunder... my head is a blur.",
	"Right. The investigation. That's why I'm here. That's why I'm still awake at this hour.",
	"Maya Reyes. Sixteen years old. Reported missing, written off as a runaway, and then forgotten. The case was abandoned a decade ago, and nobody has lifted a finger since.",
	"But someone called me. Someone wants her found. Tonight, I find out what really happened to her.",
	"The manuscript has to be finished before 6 AM. Every lead I piece together goes into it. If dawn comes and it isn't done, everything I do here is for nothing.",
	"People will come knocking. I'll hear every one of them out, but people lie, or misremember, or say what they think I want to hear. I accept only the truth, and I turn the rest away.",
	"And this place... something feels off tonight. If the lights die, or I hear something I can't explain, I stay sharp. I stay calm. Not everything here has an explanation.",
	"Alright. Let's begin.",
]
var in_intro: bool = false              # true from load until the monologue is finished (pauses clock + witnesses)
var intro_dialogue_open: bool = false   # true while the box is up and clicks advance it
var intro_index: int = 0
var intro_played: bool = false

var witnesses: Array[Node] = []
var active_witness: Node3D = null
var active_witness_id: String = ""
var current_testimony
var current_conversation: Array[StoryData.DialogueLine] = []
var conversation_index: int = 0
var in_conversation: bool = false
var _active_type_tween: Tween = null
var current_witness_id: String = ""
var returning_witnesses: Array[Node] = []
# Dictionary to store each witness's starting global transform
var initial_transforms: Dictionary = {}
var clock_label_1: Label = null
var clock_label_2: Label = null
var waiting_for_door := false
var witness_exiting := false
var welcome_already_shown: bool = false
var _run_id: int = 0   # bumps on every reset so stale awaits can bail out

func _ready() -> void:
	add_to_group("game_manager") 

	if characters_parent:
		witnesses = characters_parent.get_children()

	for witness in witnesses:
		if witness is Node3D:
			initial_transforms[witness] = witness.global_transform
		witness.visible = false
		
	_end_jumpscare()

	if wanted_poster_rect:
		if wanted_poster_texture:
			wanted_poster_rect.texture = wanted_poster_texture
		wanted_poster_rect.visible = false
	if poster_blur_rect:
		poster_blur_rect.visible = false

	next_witness_timer = witness_interval
	if door:
		door.visitor_revealed.connect(_on_visitor_revealed)
	if Accept:
		Accept.pressed.connect(_on_accept_pressed)
	if Decline:
		Decline.pressed.connect(_on_decline_pressed)

	if play_intro:
		_start_intro()

func register_clock_1(label: Label) -> void:
	clock_label_1 = label

func register_clock_2(label: Label) -> void:
	clock_label_2 = label

func update_clocks(time_str_1: String, time_str_2: String) -> void:
	if is_instance_valid(clock_label_1):
		clock_label_1.text = time_str_1
	if is_instance_valid(clock_label_2):
		clock_label_2.text = time_str_2

func _input(event: InputEvent) -> void:
	if not in_conversation and not intro_dialogue_open and not poster_pause_active:
		return

	var advance_pressed := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance_pressed = true
	elif event.is_action_pressed("ui_accept"):
		advance_pressed = true

	if not advance_pressed:
		return

	get_viewport().set_input_as_handled()

	# First input after the poster appears dismisses it and continues the intro.
	if poster_pause_active:
		_hide_wanted_poster_focus()
		intro_index += 1
		if intro_index < intro_lines.size():
			_play_intro_line(intro_index)
		else:
			_end_intro()
		return

	# If text is still typing out, finish the current line immediately.
	if _active_type_tween and _active_type_tween.is_valid() and _active_type_tween.is_running():
		_active_type_tween.kill()
		if dialogue_label:
			dialogue_label.visible_characters = -1
		return

	# Show the wanted poster after the Maya Reyes line (intro line index 3).
	if intro_dialogue_open:
		if intro_index == 3:
			_show_wanted_poster_focus()
			return

		intro_index += 1
		if intro_index < intro_lines.size():
			_play_intro_line(intro_index)
		else:
			_end_intro()
		return

	# Otherwise move to the next conversation line or into the testimony.
	conversation_index += 1
	if conversation_index < current_conversation.size():
		_play_conversation_line(conversation_index)
	else:
		_show_testimony_line()

func _show_wanted_poster_focus() -> void:
	if wanted_poster_rect == null:
		push_warning("GameManager: PosterFocusLayer/WantedPoster TextureRect is missing.")
		return
	if wanted_poster_rect.texture == null:
		push_warning("GameManager: Assign the wanted poster image to wanted_poster_texture or WantedPoster.texture.")
		return

	poster_pause_active = true
	wanted_poster_rect.visible = true
	if poster_blur_rect:
		poster_blur_rect.visible = true

func _hide_wanted_poster_focus() -> void:
	poster_pause_active = false
	if wanted_poster_rect:
		wanted_poster_rect.visible = false
	if poster_blur_rect:
		poster_blur_rect.visible = false

func _process(delta: float) -> void:
	# 1. FLOATING NAME TAG LOGIC
	if Engine.get_meta("menu_paused", false):
		return
	if active_witness and name_label and name_label.visible:
		var camera = get_viewport().get_camera_3d()
		if camera:
			var target_pos = active_witness.global_position
			
			if not camera.is_position_behind(target_pos):
				var screen_pos = camera.unproject_position(target_pos)
				
				var vertical_pixel_offset = 180.0
				name_label.global_position = Vector2(
					screen_pos.x - (name_label.size.x / 2),
					screen_pos.y - vertical_pixel_offset
				)

	# 2. TIME SHIFT LOGIC (frozen while the opening monologue is running)
	if not shift_ended and not in_intro:
		if not is_witness_busy() and not witnesses.is_empty() and not _is_blackout_active():   # <--- UPDATED
			next_witness_timer -= delta
			if next_witness_timer <= 0.0:
				_knock_for_next_witness()
		real_time_passed += delta
		_update_jumpscare_roll(delta)
		
		var current_hour = int(real_time_passed / REAL_SECONDS_PER_GAME_HOUR)
		
		var display_hour = current_hour
		if display_hour == 0:
			display_hour = 12
			
		if clock_label:
			clock_label.text = get_time_string()
			
		if current_hour >= 6:
			shift_ended = true
			_on_6_am_reached()

func _knock_for_next_witness() -> void:
	print("knock check: witnesses=", witnesses.size(), " busy=", is_witness_busy(), " waiting=", waiting_for_door, " blackout=", _is_blackout_active(), " timer=", next_witness_timer)
	if door == null or _is_blackout_active():   # <--- UPDATED
		return
	# Never knock while an anomaly event / life-lost sound is running.
	# next_witness_timer is already <= 0, so this retries every frame until it's clear.
	if _is_anomaly_active():
		return
	if door.is_open or door.is_animating or door.choosing or door.at_breaker or door.traveling:
		return
	waiting_for_door = true
	door.trigger_knock()
	
func _on_6_am_reached() -> void:
	print("6:00 AM REACHED! The shift is over.")
	if clock_label:
		clock_label.text = "6:00 AM"

func _on_visitor_revealed() -> void:
	waiting_for_door = false
	if witnesses.is_empty() and active_witness == null:
		print("All witnesses have already visited!")
		return

	if active_witness:
		var previous_witness = active_witness
		active_witness = null
		_fade_out_witness(previous_witness, func(): _reveal_next_witness())
	else:
		_reveal_next_witness()

func _reveal_next_witness() -> void:
	for w in returning_witnesses:
		if w != active_witness and not witnesses.has(w):
			witnesses.append(w)
	returning_witnesses.clear()
	if witnesses.is_empty():
		print("No more witnesses left to appear.")
		return
		
	active_witness = witnesses.pick_random() as Node3D
	witnesses.erase(active_witness)
	
	if active_witness:
		active_witness.visible = true
		_fade_in_witness(active_witness)

func _fade_in_witness(witness: Node3D) -> void:
	var tween = create_tween()

	if witness_target == null:
		push_error("CRITICAL: WitnessTarget is missing! The script cannot find it, so movement was skipped.")
	else:
		tween.tween_property(witness, "global_position", witness_target.global_position, fade_in_duration)

	var sprite = witness if "modulate" in witness else _find_sprite_child(witness)
	
	if sprite:
		var current_color = sprite.modulate
		current_color.a = 0.0
		sprite.modulate = current_color
		tween.parallel().tween_property(sprite, "modulate:a", 1.0, fade_in_duration)

	tween.finished.connect(_on_fade_finished)

func _fade_out_witness(witness: Node3D, on_complete_callback: Callable = Callable()) -> void:
	var tween = create_tween()

	if initial_transforms.has(witness):
		var target_transform: Transform3D = initial_transforms[witness]
		tween.tween_property(witness, "global_transform", target_transform, 1.5)

	var sprite = witness if "modulate" in witness else _find_sprite_child(witness)
	if sprite:
		tween.parallel().tween_property(sprite, "modulate:a", 0.0, 1.5)

	tween.finished.connect(func():
		witness.visible = false
		if on_complete_callback.is_valid():
			on_complete_callback.call()
	)

func _find_sprite_child(parent: Node) -> Node:
	for child in parent.get_children():
		if "modulate" in child:
			return child
		else:
			var found = _find_sprite_child(child)
			if found:
				return found
	return null

func _on_fade_finished() -> void:
	if active_witness:
		active_witness_id = active_witness.name.to_lower()
		if active_witness_id == "classmate1":
			active_witness_id = "classmate1_friend"
		elif active_witness_id == "classmate2":
			active_witness_id = "classmate2_bully"

		current_conversation = StoryData.draw_conversation_for_witness(active_witness_id)
		current_testimony = StoryData.draw_testimony_for_witness(active_witness_id)
		conversation_index = 0

		if name_label:
			name_label.text = "[center][b]" + StoryData.get_witness_display_name(active_witness_id) + "[/b][/center]"
			name_label.visible = true

		if Accept: Accept.visible = false
		if Decline: Decline.visible = false

		if not current_conversation.is_empty():
			in_conversation = true
			_play_conversation_line(0)
		elif current_testimony:
			_show_testimony_line()

	# FADE IN THE UI BOXES
	if dialogue_ui:
		dialogue_ui.visible = true
		if dialogue_ui.get_child_count() > 0:
			var ui_root = dialogue_ui.get_child(0)
			if "modulate" in ui_root:
				ui_root.modulate.a = 0.0
				var tween = create_tween()
				tween.tween_property(ui_root, "modulate:a", 1.0, 0.5)
				var cam = get_tree().get_first_node_in_group("player_camera")
				if cam and cam.has_method("lock_on_target"):
					cam.lock_on_target(active_witness)

func _play_conversation_line(idx: int) -> void:
	if dialogue_label == null or idx >= current_conversation.size():
		return
	var line: StoryData.DialogueLine = current_conversation[idx]
	var speaker_prefix: String = "[b]You:[/b] " if line.speaker == "player" else "[b]" + StoryData.get_witness_display_name(active_witness_id) + ":[/b] "
	dialogue_label.text = speaker_prefix + line.text + "\n[i][color=#aaaaaa](Click to continue...)[/color][/i]"
	dialogue_label.visible_characters = 0

	var total_chars := dialogue_label.get_total_character_count()
	var typing_duration := total_chars * 0.01

	if _active_type_tween and _active_type_tween.is_valid():
		_active_type_tween.kill()
	_active_type_tween = create_tween()
	_active_type_tween.tween_property(dialogue_label, "visible_characters", total_chars, typing_duration)

func _show_testimony_line() -> void:
	in_conversation = false
	if current_testimony == null or dialogue_label == null:
		return

	dialogue_label.text = current_testimony.text
	dialogue_label.visible_characters = 0

	if Accept: Accept.visible = false
	if Decline: Decline.visible = false

	var total_chars := dialogue_label.get_total_character_count()
	var typing_duration := total_chars * 0.01

	if _active_type_tween and _active_type_tween.is_valid():
		_active_type_tween.kill()
	_active_type_tween = create_tween()
	_active_type_tween.tween_property(dialogue_label, "visible_characters", total_chars, typing_duration)

	_active_type_tween.finished.connect(func():
		if Accept: Accept.visible = true
		if Decline: Decline.visible = true
	)

# ---------------- OPENING MONOLOGUE ----------------
func _start_intro() -> void:
	if intro_played or intro_lines.is_empty():
		return
	intro_played = true
	in_intro = true   # clock + witness spawning wait until the monologue ends
	dominic.set_events_paused(true)
	var my_run := _run_id

	await get_tree().create_timer(intro_start_delay, false).timeout
	if my_run != _run_id or not is_inside_tree() or not in_intro:
		return

	# Same camera lock the witnesses use (they walk to this marker)
	var cam = get_tree().get_first_node_in_group("player_camera")
	if cam and witness_target and cam.has_method("lock_on_target"):
		cam.lock_on_target(witness_target)

	# Inner monologue: no floating name tag, no Accept/Decline
	if name_label: name_label.visible = false
	if Accept: Accept.visible = false
	if Decline: Decline.visible = false

	# Same dialogue box as the testimonies, with the same fade-in
	if dialogue_ui:
		dialogue_ui.visible = true
		if dialogue_ui.get_child_count() > 0:
			var ui_root = dialogue_ui.get_child(0)
			if "modulate" in ui_root:
				ui_root.modulate.a = 0.0
				create_tween().tween_property(ui_root, "modulate:a", 1.0, 0.5)

	intro_index = 0
	intro_dialogue_open = true
	_play_intro_line(0)

func _play_intro_line(idx: int) -> void:
	if dialogue_label == null or idx >= intro_lines.size():
		return
	var hint := "Click to begin..." if idx == intro_lines.size() - 1 else "Click to continue..."
	dialogue_label.text = "[i]" + intro_lines[idx] + "[/i]\n[i][color=#aaaaaa](" + hint + ")[/color][/i]"
	dialogue_label.visible_characters = 0

	var total_chars := dialogue_label.get_total_character_count()
	var typing_duration := total_chars * 0.01

	if _active_type_tween and _active_type_tween.is_valid():
		_active_type_tween.kill()
	_active_type_tween = create_tween()
	_active_type_tween.tween_property(dialogue_label, "visible_characters", total_chars, typing_duration)

func _end_intro() -> void:
	_hide_wanted_poster_focus()
	intro_dialogue_open = false
	in_intro = false
	dominic.set_events_paused(false) 

	if _active_type_tween and _active_type_tween.is_valid():
		_active_type_tween.kill()
	_active_type_tween = null

	# Give the camera back to the player
	var cam = get_tree().get_first_node_in_group("player_camera")
	if cam and cam.has_method("unlock_camera"):
		cam.unlock_camera()

	# Fade the box out
	if dialogue_ui:
		if dialogue_ui.get_child_count() > 0:
			var ui_root = dialogue_ui.get_child(0)
			if "modulate" in ui_root:
				var ui_tween = create_tween()
				ui_tween.tween_property(ui_root, "modulate:a", 0.0, 0.4)
				ui_tween.finished.connect(func(): dialogue_ui.visible = false)
				return
		dialogue_ui.visible = false

func _on_close_button_pressed() -> void:
	in_conversation = false
	if name_label:
		name_label.visible = false
		
	var cam = get_tree().get_first_node_in_group("player_camera")
	if cam and cam.has_method("unlock_camera"):
		cam.unlock_camera()

	# 1. FADE OUT THE UI BOXES FIRST
	if dialogue_ui:
		if dialogue_ui.get_child_count() > 0:
			var ui_root = dialogue_ui.get_child(0)
			if "modulate" in ui_root:
				var ui_tween = create_tween()
				ui_tween.tween_property(ui_root, "modulate:a", 0.0, 0.4)
				ui_tween.finished.connect(func(): dialogue_ui.visible = false)
		else:
			dialogue_ui.visible = false
		
	if active_witness:
		var witness_to_dismiss = active_witness
		active_witness = null
		witness_exiting = true   # <--- ADD THIS
		
		if door:
			if door.has_method("open_door"):
				door.open_door()
			elif door.has_method("open"):
				door.open()
			elif door.has_method("interact"):
				door.interact()
		
		var my_run := _run_id
		await get_tree().create_timer(1.5, false).timeout
		if my_run != _run_id or not is_inside_tree():
			return
		
		_fade_out_witness(witness_to_dismiss, func():
			if door:
				if door.has_method("close_door"):
					door.close_door()
				elif door.has_method("close"):
					door.close()
			witness_exiting = false   # <--- ADD THIS
		)

func _on_accept_pressed() -> void:
	if current_testimony:
		if current_testimony.is_true:
			var unlocked_case = StoryData.accept_true_testimony(active_witness_id)
			if unlocked_case != "":
				Notify.show_message("Something has been unlocked.")
				
			next_witness_timer = witness_interval
		else:
			_apply_wrong_decision()
	current_testimony = null
	_on_close_button_pressed()

func _on_decline_pressed() -> void:
	if current_testimony and current_testimony.is_true:
		StoryData.release_witness(current_witness_id)
		returning_witnesses.append(active_witness)
	current_testimony = null
	_on_close_button_pressed()
	
func _apply_wrong_decision() -> void:
	wrong.play()
	next_witness_timer = witness_interval + wrong_decision_penalty
	Notify.show_message("You feel like you've made the wrong decision. The next witness won't appear soon...")
	
func hide_time() -> void:
	if clock_label:
		clock_label.get_parent().visible = false 

func show_time() -> void:
	if clock_label:
		clock_label.get_parent().visible = true

func is_witness_busy() -> bool:
	var door_has_visitor: bool = door != null and door.has_visitor
	return in_intro or active_witness != null or waiting_for_door or witness_exiting or door_has_visitor

func _is_anomaly_active() -> bool:
	var a = get_tree().get_first_node_in_group("anomaly_manager")
	return a != null and a.has_method("is_anomaly_active") and a.is_anomaly_active()

func _is_blackout_active() -> bool:
	for lm in get_tree().get_nodes_in_group("light_manager"):
		if "is_blackout" in lm and lm.is_blackout:
			return true
	return false
	
func reset_state() -> void:
	_run_id += 1

	# Stop typing / fade tweens
	if _active_type_tween and _active_type_tween.is_valid():
		_active_type_tween.kill()
	_active_type_tween = null

	_hide_wanted_poster_focus()

	# Cancel the opening monologue if a reset happens mid-way (it does not replay)
	if in_intro:
		in_intro = false
		intro_dialogue_open = false
		dominic.set_events_paused(false) 
		var intro_cam = get_tree().get_first_node_in_group("player_camera")
		if intro_cam and intro_cam.has_method("unlock_camera"):
			intro_cam.unlock_camera()

	# Jumpscare
	jumpscare_pending = false
	_jumpscare_cooldown_left = 0.0
	_jumpscare_roll_timer = 0.0
	_end_jumpscare()

	# Time
	real_time_passed = 0.0
	shift_ended = false
	if clock_label:
		clock_label.text = "12:00 AM"

	# Witness pool: rebuild from the original children, put everyone back
	returning_witnesses.clear()
	witnesses.clear()
	if characters_parent:
		witnesses = characters_parent.get_children()
	for witness in witnesses:
		if initial_transforms.has(witness):
			witness.global_transform = initial_transforms[witness]
		witness.visible = false
		var sprite = witness if "modulate" in witness else _find_sprite_child(witness)
		if sprite:
			var c = sprite.modulate
			c.a = 1.0
			sprite.modulate = c

	# Timers and flags
	next_witness_timer = witness_interval
	active_witness = null
	active_witness_id = ""
	current_witness_id = ""
	current_testimony = null
	current_conversation.clear()
	conversation_index = 0
	in_conversation = false
	waiting_for_door = false
	witness_exiting = false
	welcome_already_shown = false

	# UI
	if name_label:
		name_label.visible = false
	if dialogue_ui:
		dialogue_ui.visible = false
	if Accept: Accept.visible = false
	if Decline: Decline.visible = false

# ---------------- JUMPSCARE ----------------
func _update_jumpscare_roll(delta: float) -> void:
	if jumpscare_pending or jumpscare_playing:
		return
	if _jumpscare_cooldown_left > 0.0:
		_jumpscare_cooldown_left -= delta
		return
	if real_time_passed < jumpscare_start_time:
		return
	_jumpscare_roll_timer -= delta
	if _jumpscare_roll_timer <= 0.0:
		_jumpscare_roll_timer = jumpscare_roll_interval
		if randf() < jumpscare_chance:
			jumpscare_pending = true   # armed: will fire once the player leaves PC / bulletin board
			print("[Jumpscare] ARMED at ", int(real_time_passed), "s - waiting for player to leave PC/board")

## Called (via group "game_manager") by computer_transition.gd and Billboard.gd
## after the zoom-out animation has finished.
func on_overlay_closed() -> void:
	print("[Jumpscare] overlay closed. pending=", jumpscare_pending, " playing=", jumpscare_playing, " node_found=", jumpscare != null)
	if jumpscare_pending and not jumpscare_playing:
		_play_jumpscare()
		
func get_time_string() -> String:
	var h := int(real_time_passed / REAL_SECONDS_PER_GAME_HOUR)
	if h >= 6:
		return "6:00 AM"
	return "%d:00 AM" % (12 if h == 0 else h)
	
func _play_jumpscare() -> void:
	if jumpscare == null:
		return
	jumpscare_pending = false
	jumpscare_playing = true
	_jumpscare_cooldown_left = jumpscare_cooldown
	_jumpscare_roll_timer = jumpscare_roll_interval
	var my_run := _run_id

	print("[Jumpscare] PLAYING")
	jumpscare.visible = true
	if jumpscare_audio:
		jumpscare_audio.play()

	await get_tree().create_timer(jumpscare_duration, false).timeout
	if my_run != _run_id or not is_inside_tree():
		return   # reset_state() already cleaned up
	_end_jumpscare()

func _end_jumpscare() -> void:
	jumpscare_playing = false
	if jumpscare:
		jumpscare.visible = false
	if jumpscare_audio:
		jumpscare_audio.stop()
