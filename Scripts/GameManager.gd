extends Node

@onready var door: Area3D = $"../SubViewportContainer/SubViewport/door/Area3D"
@onready var witness_target: Marker3D = $"../WitnessTarget"

@export var dialogue_ui: CanvasLayer 
@export var dialogue_label: RichTextLabel 

@export var characters_parent: Node3D 

var witnesses: Array[Node] = []
var active_witness: Node3D = null

func _ready() -> void:
	if characters_parent:
		witnesses = characters_parent.get_children()

	for witness in witnesses:
		witness.visible = false
		
	if door:
		door.visitor_revealed.connect(_on_visitor_revealed)

func _on_visitor_revealed() -> void:
	if witnesses.is_empty():
		print("ERROR: No witnesses found in the Characters node!")
		return

	active_witness = witnesses.pick_random()
	active_witness.visible = true
	_fade_in_witness(active_witness)

func _fade_in_witness(witness: Node3D) -> void:
	var tween = create_tween()

	if witness_target == null:
		push_error("CRITICAL: WitnessTarget is missing! The script cannot find it, so movement was skipped.")
	else:
		print("DEBUG: ", witness.name, " is starting at ", witness.global_position)
		print("DEBUG: The Target is at ", witness_target.global_position)
		tween.tween_property(witness, "global_position", witness_target.global_position, 1.5)

	var sprite: Node = null
	if "modulate" in witness:
		sprite = witness
	else:
		sprite = _find_sprite_child(witness)
	
	if sprite:
		var current_color = sprite.modulate
		current_color.a = 0.0
		sprite.modulate = current_color
		tween.parallel().tween_property(sprite, "modulate:a", 1.0, 1.5)
	else:
		print("WARNING: No sprite found inside ", witness.name, " to fade.")

	tween.finished.connect(_on_fade_finished)

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
