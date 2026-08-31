extends Panel
class_name CaseSlot

signal filled(slot_category: String, evidence_id: String)

@export var expected_category: String
@onready var label: Label = $Label

var locked_in := false

func _ready() -> void:
	label.text = expected_category.capitalize()

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return not locked_in and data is Evidence and data.category == expected_category

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var evidence: Evidence = data
	locked_in = true
	label.text = evidence.display_text
	modulate = Color.WHITE
	filled.emit(expected_category, evidence.id)
