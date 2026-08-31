extends Panel
@export var evidence_data: Evidence

@onready var label: Label = $Label

func _ready() -> void:
	if evidence_data:
		label.text = evidence_data.display_text

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not evidence_data:
		return null
		
	# Create a simple preview control while dragging
	var preview := Label.new()
	preview.text = evidence_data.display_text
	set_drag_preview(preview)
	
	# Return the resource so CaseSlot can receive it in _can_drop_data
	return evidence_data
