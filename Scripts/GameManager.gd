extends Node

@onready var door: Area3D = $"../SubViewportContainer/SubViewport/door/Area3D"
@onready var witness_target: Marker3D = $"../WitnessTarget"

@export var dialogue_ui: CanvasLayer 
@export var dialogue_label: RichTextLabel 
@export var fade_in_duration: float = 0.5
@export var characters_parent: Node3D 

var witnesses: Array[Node] = []
var active_witness: Node3D = null

# Dictionary to store each witness's starting global transform
var initial_transforms: Dictionary = {}

func _ready() -> void:
	if characters_parent:
		witnesses = characters_parent.get_children()

	for witness in witnesses:
		if witness is Node3D:
			# Store initial transform so we can send them back here on fade out
			initial_transforms[witness] = witness.global_transform
		witness.visible = false
		
	if door:
		door.visitor_revealed.connect(_on_visitor_revealed)

func _on_visitor_revealed() -> void:
	if witnesses.is_empty():
		print("ERROR: No witnesses found in the Characters node!")
		return

	# If there is already an active witness, fade them out first before bringing in the new one
	if active_witness:
		var previous_witness = active_witness
		active_witness = null # Clear reference while previous fades
		_fade_out_witness(previous_witness, func(): _reveal_next_witness())
	else:
		_reveal_next_witness()

func _reveal_next_witness() -> void:
	active_witness = witnesses.pick_random() as Node3D
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
		# Changed duration from 1.5 to fade_in_duration
		tween.tween_property(witness, "global_position", witness_target.global_position, fade_in_duration)

	var sprite = witness if "modulate" in witness else _find_sprite_child(witness)
	
	if sprite:
		var current_color = sprite.modulate
		current_color.a = 0.0
		sprite.modulate = current_color
		# Changed duration from 1.5 to fade_in_duration
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
	print("DEBUG: Witness is fully visible! Showing dialogue box.")

	if dialogue_ui:
		dialogue_ui.visible = true

	if dialogue_label and active_witness:
		dialogue_label.text = "Hello! I am " + active_witness.name + ".\n(Dialogue system pending...)"
