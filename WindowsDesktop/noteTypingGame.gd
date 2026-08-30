extends Control

@onready var close_button: Button = $NotepadTitle/CloseButton
@onready var words_display: RichTextLabel = $RichTextLabel
@onready var stats_label: Label = $"Stats Label"

@export var word_list: Array[String] = ["the","quick","brown","fox","jumps",
	"over","lazy","dog","code","godot","script","window","typing","speed"]

var words: Array[String] = []
var current_word_index := 0
var typed_text := ""
var correct_chars := 0
var total_typed := 0
var time_left := 30.0
var running := false

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	words_display.bbcode_enabled = true
	_generate_words()
	_render_words()
	_update_stats()

func _on_close_pressed() -> void:
	hide()

func _generate_words(count := 40) -> void:
	words.clear()
	for i in count:
		words.append(word_list[randi() % word_list.size()])

func _process(delta: float) -> void:
	if not visible:
		return
	if running:
		time_left -= delta
		if time_left <= 0:
			_end_test()
		_update_stats()

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
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
		return
	var ch := OS.get_keycode_string(event.unicode) if event.unicode != 0 else ""
	if event.unicode != 0 and ch.length() == 1:
		if not running:
			running = true
		typed_text += ch
		_render_words()

func _submit_word() -> void:
	var target := words[current_word_index]
	total_typed += target.length()
	correct_chars += _count_correct(target, typed_text)
	current_word_index += 1
	typed_text = ""
	if current_word_index >= words.size():
		words.append_array(words.duplicate())
	_render_words()

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
	var minutes := (30.0 - time_left) / 60.0
	var wpm := 0
	if minutes > 0:
		wpm = int((correct_chars / 5.0) / minutes)
	var accuracy := 100 if total_typed == 0 else int(100.0 * correct_chars / max(total_typed, 1))
	stats_label.text = "Time: %d  WPM: %d  Acc: %d%%" % [max(int(time_left), 0), wpm, accuracy]

func _end_test() -> void:
	running = false
	stats_label.text += "  [DONE]"
