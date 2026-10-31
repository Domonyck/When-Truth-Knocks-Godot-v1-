extends TextureButton

@onready var mouse: AudioStreamPlayer = $Mouse
@onready var notepad_ui: Control = $"../Notepad2"

func _pressed() -> void:
	if mouse:
		mouse.play()

	var active_case_id := _get_current_active_case()
	if active_case_id != "":
		notepad_ui.start_manuscript(active_case_id)
	elif StoryData.is_run_complete():
		Notify.show_message("There's nothing left to write.")
	else:
		Notify.show_message("You feel like you're missing something.")

func _get_current_active_case() -> String:
	# Iterate through cases in article sequence order
	for case_id in StoryData.order:
		# Check if unlocked, puzzle solved (or intro), and not yet finished
		if StoryData.is_unlocked(case_id) and StoryData.is_puzzle_solved(case_id):
			if not StoryData.cases[case_id].solved:
				return case_id
	return ""
