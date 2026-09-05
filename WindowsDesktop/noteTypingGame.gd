extends Control
# Requires the "StoryData" autoload (see story_data.gd) to be registered in
# Project Settings > Autoload before this will work.
#
# Scope note: this is only the typing step of the loop. Whoever builds the
# bulletin puzzle just needs to call notepad.start_manuscript(case_id)
# once that case's puzzle is solved.

signal manuscript_typed(case_id: String)
signal manuscript_failed(case_id: String)

@onready var close_button: Button = $NotepadTitle/CloseButton
@onready var words_display: RichTextLabel = $RichTextLabel
@onready var stats_label: Label = $"Stats Label"

## If accuracy drops below this while typing, the manuscript resets and
## has to be typed from the beginning. Tune from the Inspector.
@export var min_accuracy_percent: float = 40.0

var case_id: String = ""
var words: Array[String] = []
var current_word_index := 0
var typed_text := ""
var correct_chars := 0
var total_typed := 0
var finished := false

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	words_display.bbcode_enabled = true
	hide()

## Extra safety net: whatever forces this window closed (close button,
## force_shutdown_desktop(), or anything else just setting .visible =
## false directly) triggers one last save, in case it happens between
## keystrokes.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible and not finished:
		_save_progress()

## Call this once the bulletin board puzzle for this case has been solved:
##   notepad.start_manuscript("case1")
## If the player was interrupted mid-typing (e.g. power cut and the
## desktop got force-closed), this resumes from where they left off
## instead of restarting the manuscript.
func start_manuscript(id: String) -> void:
	if not StoryData.cases.has(id):
		push_warning("No case with id '%s' in Story data." % id)
		return
	if not StoryData.is_unlocked(id):
		push_warning("Case '%s' has not been unlocked (true testimony not yet heard)." % id)
		return
	case_id = id
	finished = false
	words.clear()
	for word in StoryData.get_manuscript_text(id).split(" ", false):
		words.append(word)
	current_word_index = clamp(StoryData.get_progress_word_index(id), 0, words.size())
	typed_text = StoryData.get_progress_typed_text(id)
	total_typed = StoryData.get_progress_total_typed(id)
	correct_chars = StoryData.get_progress_correct_chars(id)
	_render_words()
	_update_stats()
	show()

func _on_close_pressed() -> void:
	hide()

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or finished:
		return
	if not (event is InputEventKey and event.pressed):
		return
	if event.keycode == KEY_SPACE:
		_submit_word()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_BACKSPACE:
		typed_text = typed_text.substr(0, max(0, typed_text.length() - 1))
		_render_words()
		_save_progress()
		return
	var ch := OS.get_keycode_string(event.unicode) if event.unicode != 0 else ""
	if event.unicode != 0 and ch.length() == 1:
		typed_text += ch
		_render_words()
		_save_progress()

func _submit_word() -> void:
	if words.is_empty() or current_word_index >= words.size():
		return
	var target := words[current_word_index]
	total_typed += target.length()
	correct_chars += _count_correct(target, typed_text)
	current_word_index += 1
	typed_text = ""

	if _current_accuracy() < min_accuracy_percent:
		_fail_and_reset()
		return

	if current_word_index >= words.size():
		_finish_manuscript()
	else:
		_render_words()
		_save_progress()
	_update_stats()

func _current_accuracy() -> float:
	if total_typed == 0:
		return 100.0
	return 100.0 * correct_chars / total_typed

## Accuracy dropped below the threshold: wipe progress on this manuscript
## (both locally and in Story) and make the player start it over.
func _fail_and_reset() -> void:
	current_word_index = 0
	typed_text = ""
	correct_chars = 0
	total_typed = 0
	StoryData.reset_progress(case_id)
	stats_label.text = "Accuracy dropped below %d%%. Start the manuscript over." % int(min_accuracy_percent)
	_render_words()
	manuscript_failed.emit(case_id)

## Persist progress into Story (the autoload) so it survives this node
## being hidden or force-closed by another system.
func _save_progress() -> void:
	if case_id != "":
		StoryData.save_progress(case_id, current_word_index, typed_text, total_typed, correct_chars)

func _count_correct(target: String, typed: String) -> int:
	var n: int = min(target.length(), typed.length())
	var c := 0
	for i in n:
		if target[i] == typed[i]:
			c += 1
	return c

func _render_words() -> void:
	var bbcode := ""
	for i in words.size():
		var w := words[i]
		if i < current_word_index:
			bbcode += "[color=gray]%s[/color] " % w
		elif i == current_word_index:
			bbcode += _colorize_current(w) + " "
		else:
			bbcode += w + " "
	words_display.text = bbcode

func _colorize_current(word: String) -> String:
	var out := ""
	for i in word.length():
		if i < typed_text.length():
			out += "[color=%s]%s[/color]" % [
				("lime" if typed_text[i] == word[i] else "red"), word[i]
			]
		else:
			out += "[color=white]%s[/color]" % word[i]
	if typed_text.length() > word.length():
		out += "[color=red]%s[/color]" % typed_text.substr(word.length())
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
