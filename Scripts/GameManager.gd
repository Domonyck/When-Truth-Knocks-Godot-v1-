extends Node

@onready var door: Area3D = $"../SubViewportContainer/SubViewport/door/Area3D"
@onready var witness_target: Marker3D = $"../WitnessTarget"

@export var dialogue_ui: CanvasLayer 
@export var name_label: RichTextLabel 
@export var dialogue_label: RichTextLabel 
@export var Accept: Button
@export var Decline: Button
@export var fade_in_duration: float = 1.5
@export var characters_parent: Node3D 

var witnesses: Array[Node] = []
var active_witness: Node3D = null

# Dictionary to store each witness's starting global transform
var initial_transforms: Dictionary = {}

func _ready() -> void:
	if Accept:
		Accept.pressed.connect(_on_close_button_pressed)

	if Decline:
		Decline.pressed.connect(_on_close_button_pressed)

	if characters_parent:
		witnesses = characters_parent.get_children()

	for witness in witnesses:
		if witness is Node3D:
			initial_transforms[witness] = witness.global_transform
		witness.visible = false
		
	if door:
		door.visitor_revealed.connect(_on_visitor_revealed)

func _process(delta: float) -> void:
	if active_witness and name_label and name_label.visible:
		var camera = get_viewport().get_camera_3d()
		if camera:
			# Use the character's exact global position (their center/origin point)
			var target_pos = active_witness.global_position
			
			if not camera.is_position_behind(target_pos):
				# Get the 2D screen coordinates of the character's center
				var screen_pos = camera.unproject_position(target_pos)
				
				var vertical_pixel_offset = 180.0
				name_label.global_position = Vector2(
					screen_pos.x - (name_label.size.x / 2),
					screen_pos.y - vertical_pixel_offset
				)

func _on_visitor_revealed() -> void:
	# If the pool is empty AND the room is empty, do nothing
	if witnesses.is_empty() and active_witness == null:
		print("All witnesses have already visited!")
		return

	# If there is already an active witness, fade them out first
	if active_witness:
		var previous_witness = active_witness
		active_witness = null # Clear reference while previous fades
		_fade_out_witness(previous_witness, func(): _reveal_next_witness())
	else:
		_reveal_next_witness()

func _reveal_next_witness() -> void:
	# Check again before picking, in case the very last person just left
	if witnesses.is_empty():
		print("No more witnesses left to appear.")
		return
		
	active_witness = witnesses.pick_random() as Node3D
	
	# KEY ADDITION: Remove the chosen witness from the pool so they can't be picked again
	witnesses.erase(active_witness)
	
	if active_witness:
		active_witness.visible = true
		_fade_in_witness(active_witness)

func _fade_in_witness(witness: Node3D) -> void:
	var tween = create_tween()

	if witness_target == null:
		push_error("CRITICAL: WitnessTarget is missing! The script cannot find it, so movement was skipped.")
	else:
		print("DEBUG: ", witness.name, " is starting at ", witness.global_position)
		print("DEBUG: The Target is at ", witness_target.global_position)
		tween.tween_property(witness, "global_position", witness_target.global_position, fade_in_duration)

	var sprite = witness if "modulate" in witness else _find_sprite_child(witness)
	
	if sprite:
		var current_color = sprite.modulate
		current_color.a = 0.0
		sprite.modulate = current_color
		tween.parallel().tween_property(sprite, "modulate:a", 1.0, fade_in_duration)
	else:
		print("WARNING: No sprite found inside ", witness.name, " to fade.")

	tween.finished.connect(_on_fade_finished)

func _fade_out_witness(witness: Node3D, on_complete_callback: Callable = Callable()) -> void:
	var tween = create_tween()

	# Move back to original starting transform
	if initial_transforms.has(witness):
		var target_transform: Transform3D = initial_transforms[witness]
		tween.tween_property(witness, "global_transform", target_transform, 1.5)

	# Fade out opacity
	var sprite = witness if "modulate" in witness else _find_sprite_child(witness)
	if sprite:
		tween.parallel().tween_property(sprite, "modulate:a", 0.0, 1.5)

	# Once fade-out finishes, hide the node and trigger callback
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
		# Format the 2D Node name to match StoryData IDs
		var witness_id: String = active_witness.name.to_lower()
		if witness_id == "classmate1":
			witness_id = "classmate1_friend"
		elif witness_id == "classmate2":
			witness_id = "classmate2_bully"

		# Draw the testimony from the data manager
		var testimony = StoryData.draw_testimony_for_witness(witness_id)
		
		if testimony:
			# Send the Name to the Left Box
			if name_label:
				name_label.text = "[center][b]" + StoryData.get_witness_display_name(witness_id) + "[/b][/center]"
				name_label.visible = true
			
			# Send the Testimony to the Bottom Box and Type it out
			if dialogue_label:
				dialogue_label.text = testimony.text
				dialogue_label.visible_characters = 0 # Hide text initially
				
				# Hide buttons before typing starts
				if Accept: Accept.visible = false
				if Decline: Decline.visible = false
				
				# Calculate typing duration (0.03 seconds per character)
				var text_length = testimony.text.length()
				var typing_duration = text_length * 0.01 
				
				# Animate the text appearing
				var type_tween = create_tween()
				type_tween.tween_property(dialogue_label, "visible_characters", text_length, typing_duration)
				
				# Show the buttons once typing is finished
				type_tween.finished.connect(func():
					if Accept: Accept.visible = true
					if Decline: Decline.visible = true
				)
			
			# Process the true/false logic to advance the game state
			if testimony.is_true:
				var unlocked_case = StoryData.accept_true_testimony()
				if unlocked_case != "":
					print("PROGRESS: True testimony accepted! Unlocked case: ", unlocked_case)

	# FADE IN THE UI BOXES
	if dialogue_ui:
		dialogue_ui.visible = true
		# Grab the main Control node inside the CanvasLayer
		if dialogue_ui.get_child_count() > 0:
			var ui_root = dialogue_ui.get_child(0)
			if "modulate" in ui_root:
				ui_root.modulate.a = 0.0 # Start invisible
				var tween = create_tween()
				tween.tween_property(ui_root, "modulate:a", 1.0, 0.5) # Fade to fully visible over 0.5s
				var cam = get_tree().get_first_node_in_group("player_camera")
				if cam and cam.has_method("lock_on_target"):
					cam.lock_on_target(active_witness)
					
func _on_close_button_pressed() -> void:
	# --- NEW: Hide name tag and unlock camera immediately ---
	if name_label:
		name_label.visible = false
		
	var cam = get_tree().get_first_node_in_group("player_camera")
	if cam and cam.has_method("unlock_camera"):
		cam.unlock_camera()
	# --------------------------------------------------------

	# 1. FADE OUT THE UI BOXES FIRST
	if dialogue_ui:
		if dialogue_ui.get_child_count() > 0:
			var ui_root = dialogue_ui.get_child(0)
			if "modulate" in ui_root:
				var ui_tween = create_tween()
				ui_tween.tween_property(ui_root, "modulate:a", 0.0, 0.4) # Fade to invisible over 0.4s
				ui_tween.finished.connect(func(): dialogue_ui.visible = false)
		else:
			dialogue_ui.visible = false
		
	if active_witness:
		var witness_to_dismiss = active_witness
		active_witness = null # Clear the room status
		
		# 2. Command the door to open BEFORE the character moves.
		if door:
			if door.has_method("open_door"):
				door.open_door()
			elif door.has_method("open"):
				door.open()
			elif door.has_method("interact"):
				door.interact()
		
		# 3. Wait 1.5 seconds for the door animation to finish opening
		await get_tree().create_timer(1.5).timeout
		
		# 4. Trigger the character's 1.5-second exit tween. 
		# When they finish fading out, the door automatically closes behind them.
		_fade_out_witness(witness_to_dismiss, func():
			if door:
				if door.has_method("close_door"):
					door.close_door()
				elif door.has_method("close"):
					door.close()
		)
