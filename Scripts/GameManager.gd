extends Node

@onready var door: Area3D = get_node_or_null("../SubViewportContainer/SubViewport/door/Area3D")
@onready var witness_target: Marker3D = get_node_or_null("../WitnessTarget")
@onready var wrong: AudioStreamPlayer = get_node_or_null("../WrongDecision")
@export var dialogue_ui: CanvasLayer 
@export var name_label: RichTextLabel 
@export var dialogue_label: RichTextLabel 
@export var Accept: Button
@export var Decline: Button
@export var fade_in_duration: float = 1.5
@export var characters_parent: Node3D 

# --- TIME MANAGEMENT VARIABLES ---
@export_group("Time Management")
@export var clock_label: Label
var real_time_passed: float = 0.0
const REAL_SECONDS_PER_GAME_HOUR: float = 120.0 # 120 seconds = 2 real minutes
var shift_ended: bool = false
# ---------------------------------
@export_group("Witness Spawning")
@export var witness_interval: float = 60.0      # base time between witnesses
@export var wrong_decision_penalty: float = 20.0 # extra delay for a wrong choice
var next_witness_timer: float = 60.0

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
		
	next_witness_timer = witness_interval
	if door:
		door.visitor_revealed.connect(_on_visitor_revealed)
	if Accept:
		Accept.pressed.connect(_on_accept_pressed)
	if Decline:
		Decline.pressed.connect(_on_decline_pressed)
		
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
	if not in_conversation:
		return
	var advance_pressed := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance_pressed = true
	elif event.is_action_pressed("ui_accept"):
		advance_pressed = true

	if advance_pressed:
		get_viewport().set_input_as_handled()
		# If text is still typing out, finish the current line immediately
		if _active_type_tween and _active_type_tween.is_valid() and _active_type_tween.is_running():
			_active_type_tween.kill()
			if dialogue_label:
				dialogue_label.visible_characters = -1
			return

		# Otherwise move to the next conversation line or into the testimony
		conversation_index += 1
		if conversation_index < current_conversation.size():
			_play_conversation_line(conversation_index)
		else:
			_show_testimony_line()
		
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

	# 2. TIME SHIFT LOGIC
	if not shift_ended:
		if not is_witness_busy() and not witnesses.is_empty() and not _is_blackout_active():   # <--- UPDATED
			next_witness_timer -= delta
			if next_witness_timer <= 0.0:
				_knock_for_next_witness()
		real_time_passed += delta
		
		var current_hour = int(real_time_passed / REAL_SECONDS_PER_GAME_HOUR)
		
		var display_hour = current_hour
		if display_hour == 0:
			display_hour = 12
			
		if clock_label:
			clock_label.text = str(display_hour) + ":00 AM"
			
		if current_hour >= 6:
			shift_ended = true
			_on_6_am_reached()

func _knock_for_next_witness() -> void:
	if door == null or _is_blackout_active():   # <--- UPDATED
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
	return active_witness != null or waiting_for_door or witness_exiting or door_has_visitor

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
