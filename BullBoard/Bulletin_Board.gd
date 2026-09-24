extends Control

signal stage_solved(stage_name: String)
signal stage_failed(stage_name: String)
signal puzzle_solved()

@onready var timer_label: Label = $TimerLabel
@onready var status_label: Label = $StatusLabel
@onready var bg_music: AudioStreamPlayer = $FreesoundCommunityCreepyDistortion29539
@onready var correct_ans: AudioStreamPlayer = $FreesoundCommunityServiceBellRing14610
@onready var wrong_ans: AudioStreamPlayer = $Mrstokes302808Mrstokes302454992
## How long the player has to find every item in a stage before it fails.
@export var time_limit_seconds: float = 30.0
## Time deducted from the countdown for a "reckless" click (missing every
## item and hitting the background instead).
@export var wrong_click_penalty_seconds: float = 5.0
## Automatically move to the next stage a moment after the current one is solved.
@export var auto_advance: bool = true
@export var advance_delay_seconds: float = 1.0
## After the LAST stage is solved, this scene frees itself (queue_free) so
## whatever spawned it (e.g. Billboard.gd) can detect tree_exited and play
## its zoom-out animation. Set to false if you'd rather close it manually.
@export var auto_close_on_solved: bool = true
@export var auto_close_delay_seconds: float = 1.5

const FOUND_TINT := Color(0.5, 1.0, 0.5, 0.55)
const WRONG_FLASH := Color(1.0, 0.4, 0.4)

var stages: Array[Panel] = []
var stage_buttons: Dictionary = {}     # stage_name -> Array[TextureButton]
var stage_backgrounds: Dictionary = {} # stage_name -> Control

var current_stage: Panel = null
var found_count: int = 0
var time_remaining: float = 0.0
var active := false
var _flash_token := 0
var _closing := false

# NOTE ON ESC / PAUSE:
# When this scene is opened as a paused overlay (e.g. by Billboard.gd,
# which sets get_tree().paused = true), the node that spawned it stops
# receiving _input entirely unless its process_mode is ALWAYS — but this
# overlay's root DOES get set to PROCESS_MODE_ALWAYS by whoever opens it,
# so it's the right place to listen for the close key. Closing here
# (queue_free) fires this node's tree_exited signal, which is what
# Billboard.gd listens to in order to play its zoom-out animation.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()

func _close() -> void:
	if _closing:
		return
	_closing = true
	queue_free()

func _ready() -> void:
	bg_music.play()
	for child in get_children():
		if child is Panel:
			var stage: Panel = child
			stages.append(stage)
			_setup_stage(stage)

	if stages.is_empty():
		push_warning("BulletinBoard: no Stage panels found as direct children.")
		return

	# Start on whichever stage is already visible in the editor (defaults
	# to the first one), everything else gets hidden.
	var start_stage: Panel = stages[0]
	for stage in stages:
		if stage.visible:
			start_stage = stage
			break
	_start_stage(start_stage)

func _setup_stage(stage: Panel) -> void:
	var buttons: Array[TextureButton] = []
	var background: Control = null

	for child in stage.get_children():
		if child is TextureButton:
			var btn: TextureButton = child
			buttons.append(btn)
			btn.pressed.connect(_on_item_pressed.bind(btn, stage))
		elif background == null and child is Control:
			background = child

	stage_buttons[stage.name] = buttons

	if background:
		background.mouse_filter = Control.MOUSE_FILTER_STOP
		background.gui_input.connect(_on_background_gui_input.bind(stage))
		stage_backgrounds[stage.name] = background
	else:
		push_warning("BulletinBoard: stage '%s' has no background Control to catch reckless clicks." % stage.name)

func _process(delta: float) -> void:
	if not active:
		return
	time_remaining = max(0.0, time_remaining - delta)
	timer_label.text = "Time: %d" % ceil(time_remaining)
	if time_remaining <= 0.0:
		_on_time_up()

## Switch to a stage by name (e.g. "Stage2") and (re)start its timer.
func go_to_stage(stage_name: String) -> void:
	for stage in stages:
		if stage.name == stage_name:
			_start_stage(stage)
			return
	push_warning("BulletinBoard: no stage named '%s'." % stage_name)

func _start_stage(stage: Panel) -> void:
	current_stage = stage
	found_count = 0
	time_remaining = time_limit_seconds
	active = true

	for s in stages:
		s.visible = (s == stage)

	for btn in stage_buttons.get(stage.name, []):
		btn.disabled = false
		btn.modulate = Color.WHITE

	_update_status()

func _on_item_pressed(obj: TextureButton, stage: Panel) -> void:
	if not active or stage != current_stage:
		return
	if correct_ans:
		correct_ans.play()
	obj.disabled = true
	obj.modulate = FOUND_TINT
	found_count += 1
	_update_status()

	var total: int = stage_buttons[stage.name].size()
	if found_count >= total:
		_on_stage_solved(stage)

func _on_background_gui_input(event: InputEvent, stage: Panel) -> void:
	if not active or stage != current_stage:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_apply_wrong_click_penalty(stage)

func _apply_wrong_click_penalty(stage: Panel) -> void:
	if wrong_ans:
		wrong_ans.play()
		
	time_remaining = max(0.0, time_remaining - wrong_click_penalty_seconds)

	if stage:
		var original := stage.modulate
		stage.modulate = WRONG_FLASH
		_flash_token += 1
		var token := _flash_token
		await get_tree().create_timer(0.15).timeout
		if is_instance_valid(stage) and token == _flash_token:
			stage.modulate = original

	status_label.text = "Careless click! -%ds" % int(wrong_click_penalty_seconds)
	_flash_token += 1
	var status_token := _flash_token
	await get_tree().create_timer(0.6).timeout
	if active and status_token == _flash_token:
		_update_status()

func _on_stage_solved(stage: Panel) -> void:
	active = false
	status_label.text = "Stage complete!"
	timer_label.text = ""
	stage_solved.emit(stage.name)

	if not auto_advance:
		return

	var idx := stages.find(stage)
	if idx == stages.size() - 1:
		puzzle_solved.emit()
		if auto_close_on_solved:
			await get_tree().create_timer(auto_close_delay_seconds).timeout
			_close()
		return

	await get_tree().create_timer(advance_delay_seconds).timeout
	_start_stage(stages[idx + 1])

func _on_time_up() -> void:
	active = false
	timer_label.text = "Time: 0"
	var total: int = stage_buttons[current_stage.name].size()
	status_label.text = "Out of time. (%d/%d found — try again.)" % [found_count, total]
	stage_failed.emit(current_stage.name)

	# Pause briefly so the player can see the "Out of time" message before closing
	await get_tree().create_timer(1.5).timeout
	
	# Close and free the bulletin board scene
	_close()

func _update_status() -> void:
	if current_stage == null:
		return
	var total: int = stage_buttons[current_stage.name].size()
	status_label.text = "Evidence found: %d / %d" % [found_count, total]
