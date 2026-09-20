extends Control

signal manuscript_typed(case_id: String)
signal manuscript_failed(case_id: String)

@onready var close_button: Button = $NotepadTitle/CloseButton
@onready var words_display: RichTextLabel = $RichTextLabel
@onready var stats_label: Label = $"Stats Label"
@onready var keyboard_393908: AudioStreamPlayer = $Keyboard393908
@onready var space_bar_press_slightly_loud_94422: AudioStreamPlayer = $SpaceBarPressSlightlyLoud94422
@onready var mouse: AudioStreamPlayer = $Mouse

@export var min_accuracy_percent: float = 80.0

var case_id: String = ""
var words: Array[String] = []
var word_states: Array[bool] = []  # Stores true if typed correctly, false if incorrect/missed
var current_word_index := 0
var typed_text := ""
var correct_chars := 0
var total_typed := 0
var finished := false

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	space_bar_press_slightly_loud_94422.pitch_scale = 2.0
	words_display.bbcode_enabled = true
	hide()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible and not finished:
		_save_progress()

func start_manuscript(id: String) -> void:
	if not StoryData.cases.has(id):
		push_warning("No case with id '%s' in Story data." % id)
		return
	if not StoryData.is_unlocked(id):
		push_warning("Case '%s' has not been unlocked (true testimony not yet heard)." % id)
		return
	if not StoryData.is_puzzle_solved(id):
		push_warning("Case '%s' bulletin puzzle not solved yet." % id)
		return
		
	words_display.bbcode_enabled = true
	case_id = id
	finished = false
	words.clear()
	
	for word in StoryData.get_manuscript_text(id).split(" ", false):
		words.append(word)
		
	current_word_index = clamp(StoryData.get_progress_word_index(id), 0, words.size())
	typed_text = StoryData.get_progress_typed_text(id)
	total_typed = StoryData.get_progress_total_typed(id)
	correct_chars = StoryData.get_progress_correct_chars(id)
	
	# Only pad with true if word_states is completely empty when loading progress
	if word_states.is_empty():
		for i in current_word_index:
			word_states.append(true)
		
	_render_words()
	_update_stats()
	show()

func _on_close_pressed() -> void:
	mouse.play()
	hide()

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or finished:
		return
	if not (event is InputEventKey and event.pressed):
		return
		
	# ONLY Space is allowed to submit words
	if event.keycode == KEY_SPACE:
		space_bar_press_slightly_loud_94422.play()
		_submit_word()
		get_viewport().set_input_as_handled()
		return
		
	if event.keycode == KEY_BACKSPACE:
		keyboard_393908.play()
		typed_text = typed_text.substr(0, max(0, typed_text.length() - 1))
		_render_words()
		_save_progress()
		get_viewport().set_input_as_handled()
		return
	
	# Block Enter keys from adding invisible newlines into typed_text
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		return

	if event.unicode >= 32 and event.unicode != 127:
		var ch := String.chr(event.unicode)
		keyboard_393908.play()
		typed_text += ch
		_render_words()
		_save_progress()
		get_viewport().set_input_as_handled()

func _submit_word() -> void:
	if words.is_empty() or current_word_index >= words.size():
		return
	var target := words[current_word_index]
	
	var correct_in_word := _count_correct(target, typed_text)
	total_typed += target.length()
	correct_chars += correct_in_word
	
	# Check if the word was typed 100% accurately
	var is_fully_correct := (typed_text == target)
	
	if current_word_index < word_states.size():
		word_states[current_word_index] = is_fully_correct
	else:
		word_states.append(is_fully_correct)
	
	current_word_index += 1
	typed_text = ""

	# Render immediately so the submitted red/green state is drawn on screen
	_render_words()
	_update_stats()

	# If accuracy fails, call reset (which now pauses so the red word stays visible)
	if _current_accuracy() < min_accuracy_percent:
		_fail_and_reset()
		return

	if current_word_index >= words.size():
		_finish_manuscript()
	else:
		_save_progress()

func _current_accuracy() -> float:
	if total_typed == 0:
		return 100.0
	return 100.0 * correct_chars / total_typed

func _fail_and_reset() -> void:
	stats_label.text = "Accuracy dropped below %d%%. Restarting..." % int(min_accuracy_percent)
	
	# Hold for 0.8 seconds so the player actually sees the red word before wiping
	await get_tree().create_timer(0.8).timeout
	
	current_word_index = 0
	typed_text = ""
	correct_chars = 0
	total_typed = 0
	word_states.clear()
	StoryData.reset_progress(case_id)
	
	_render_words()
	_update_stats()
	manuscript_failed.emit(case_id)

func _save_progress() -> void:
	if case_id != "":
		StoryData.save_progress(case_id, current_word_index, typed_text, total_typed, correct_chars)

func _count_correct(target: String, typed: String) -> int:
	var n: int = min(target.length(), typed.length())
	var c := 0
	for i in n:
		if target.substr(i, 1) == typed.substr(i, 1):
			c += 1
	return c

func _render_words() -> void:
	var bbcode := ""
	for i in words.size():
		var w := words[i]
		if i < current_word_index:
			var is_correct := true
			if i < word_states.size():
				is_correct = word_states[i]
			
			var color_hex := "#00FF00" if is_correct else "#FF0000"
			bbcode += "[color=%s]%s[/color] " % [color_hex, w]
		elif i == current_word_index:
			bbcode += _colorize_current(w) + " "
		else:
			bbcode += "[color=#FFFFFF]%s[/color] " % w
			
	words_display.text = bbcode

func _colorize_current(word: String) -> String:
	var out := ""
	var word_len := word.length()
	var typed_len := typed_text.length()
	
	for i in word_len:
		if i < typed_len:
			var target_char := word.substr(i, 1)
			var typed_char := typed_text.substr(i, 1)
			
			if typed_char == target_char:
				out += "[color=#00FF00]%s[/color]" % target_char
			else:
				# Render incorrect characters in RED
				out += "[color=#FF0000]%s[/color]" % typed_char
		else:
			# Untyped characters in current word
			out += "[color=#FFFFFF]%s[/color]" % word.substr(i, 1)
	
	# Extra typed characters beyond word length in RED
	if typed_len > word_len:
		out += "[color=#FF0000]%s[/color]" % typed_text.substr(word_len)
		
	return out

func _update_stats() -> void:
	var accuracy := int(_current_accuracy())
	stats_label.text = "Progress: %d / %d words   Accuracy: %d%%" % [current_word_index, words.size(), accuracy]

func _finish_manuscript() -> void:
	finished = true
	StoryData.mark_case_solved(case_id)
	stats_label.text += "   [Manuscript filed]"
	_render_words()
	manuscript_typed.emit(case_id)
