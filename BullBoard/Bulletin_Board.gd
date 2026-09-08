extends Control
# Requires the "StoryData" autoload to be registered in
# Project Settings > Autoload (see Story_Data.gd).
#
# HOW THE PUZZLE WORKS (hidden object):
#   For the open case, StoryData lists 5 correct evidence item ids
#   (StoryData.get_evidence_items(case_id)). The scene itself contains a
#   background image and a bunch of clickable objects scattered over it —
#   the 5 correct ones PLUS as many decoys as you want for set dressing.
#     - click a correct item  -> it's marked found (grayed out/disabled),
#       can't be clicked again. Find all 5 -> puzzle solved.
#     - click anything else   -> counts as a wrong click: no story effect,
#       but it costs the player time off the countdown.
#     - timer hits 0 before all 5 are found -> puzzle_failed fires. Items
#       already found STAY found (see StoryData.reset_puzzle_progress if
#       you'd rather a timeout wipe everything and force a full re-find).
#
# SCENE SETUP:
#   Control "BulletinBoard"                 <- this script
#     TextureRect "Background"              <- the scene art for this case
#     Node "ClickableObjects"               <- plain Node/Control, holds every clickable
#       TextureButton "school_photo"        <- name MUST exactly match an id from
#       TextureButton "torn_diary_page"        StoryData.get_evidence_items() for this
#       TextureButton "phone_messages"         case to count as a correct item...
#       TextureButton "hall_pass_log"
#       TextureButton "class_schedule"
#       TextureButton "coffee_mug"           <- ...anything else is just a decoy.
#       TextureButton "stack_of_papers"          Name decoys whatever you like, they
#       TextureButton "wall_clock"               just can't collide with a real id.
#     Label "TimerLabel"
#     Label "StatusLabel"
#
#   TextureButton is recommended over a plain Button so you can place actual
#   object art at arbitrary positions/rotations over the background. Give
#   each one a texture_normal and (optionally) a click_mask in the Inspector
#   so the player has to click the actual object shape, not its bounding box.
#
#   Because each case has different art/objects, the natural setup is one
#   scene per case (BulletinBoard_Case1.tscn, _Case2, _Case3), all using
#   this same script — rather than trying to reuse one scene and hot-swap
#   the background and object layout at runtime.
#
# HOOK: whoever opens this board calls board.open_case("case1") once that
# case is unlocked (StoryData.is_unlocked("case1") == true). Listen for
# puzzle_solved(case_id) to know when to let the player go type the
# manuscript (notepad.start_manuscript(case_id)).

signal puzzle_solved(case_id: String)
signal puzzle_failed(case_id: String)

@onready var clickable_objects: Node = $ClickableObjects
@onready var timer_label: Label = $TimerLabel
@onready var status_label: Label = $StatusLabel

## How long the player has to find all 5 items before the attempt fails.
@export var time_limit_seconds: float = 45.0
## Time deducted from the countdown for every wrong click (a decoy, or a
## correct item that's already been found).
@export var wrong_click_penalty_seconds: float = 5.0

const FOUND_TINT := Color(0.5, 1.0, 0.5, 0.55)
const WRONG_FLASH := Color(1.0, 0.4, 0.4)

var case_id: String = ""
var target_items: Array[String] = []
var found_items: Array[String] = []
var time_remaining: float = 0.0
var active := false   # false while board closed, already solved, or timed out

func _ready() -> void:
	for child in clickable_objects.get_children():
		if child is Control and child.has_signal("pressed"):
			var obj: Control = child
			obj.pressed.connect(_on_object_pressed.bind(obj))
		else:
			push_warning("BulletinBoard: '%s' has no 'pressed' signal — use Button/TextureButton." % child.name)
	hide()

func _process(delta: float) -> void:
	if not active:
		return
	time_remaining = max(0.0, time_remaining - delta)
	timer_label.text = "Time: %d" % ceil(time_remaining)
	if time_remaining <= 0.0:
		_on_time_up()

## Call this to open the board for a specific, already-unlocked case.
func open_case(id: String) -> void:
	if not StoryData.cases.has(id):
		push_warning("BulletinBoard: no case '%s'." % id)
		return
	if not StoryData.is_unlocked(id):
		push_warning("BulletinBoard: case '%s' not unlocked yet (no true testimony heard)." % id)
		return

	case_id = id
	target_items = StoryData.get_evidence_items(id)
	found_items = StoryData.get_found_items(id)
	var solved := StoryData.is_puzzle_solved(id)
	time_remaining = time_limit_seconds
	active = not solved

	_refresh_object_states(solved)
	_update_status()
	if solved:
		status_label.text = "Case solved — all evidence filed."
		timer_label.text = ""
	show()

func _refresh_object_states(solved: bool) -> void:
	for obj in clickable_objects.get_children():
		var id: String = obj.name
		if id in found_items:
			obj.disabled = true
			obj.modulate = FOUND_TINT
		else:
			obj.disabled = solved
			obj.modulate = Color.WHITE

func _on_object_pressed(obj: Node) -> void:
	if not active:
		return
	var id: String = obj.name

	if id in target_items and id not in found_items:
		found_items.append(id)
		var just_completed: bool = StoryData.mark_item_found(case_id, id)
		obj.disabled = true
		obj.modulate = FOUND_TINT
		_update_status()
		if just_completed:
			_on_all_found()
		return

	# Wrong click: a decoy, or a correct item that was already found.
	_apply_wrong_click_penalty(obj)

func _apply_wrong_click_penalty(obj: Node) -> void:
	time_remaining = max(0.0, time_remaining - wrong_click_penalty_seconds)
	var original := obj.modulate
	obj.modulate = WRONG_FLASH
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(obj) and obj.modulate == WRONG_FLASH:
		obj.modulate = original

func _on_all_found() -> void:
	active = false
	status_label.text = "All evidence found!"
	timer_label.text = ""
	puzzle_solved.emit(case_id)

func _on_time_up() -> void:
	active = false
	timer_label.text = "Time: 0"
	status_label.text = "Out of time. (%d/%d found — try again.)" % [found_items.size(), target_items.size()]
	puzzle_failed.emit(case_id)

func _update_status() -> void:
	status_label.text = "Evidence found: %d / %d" % [found_items.size(), target_items.size()]
