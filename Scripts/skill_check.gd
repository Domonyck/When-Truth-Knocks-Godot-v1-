extends Control

signal finished(result: String)   # "great", "good" or "miss"

@export var radius := 90.0
@export var good_arc := deg_to_rad(40.0)
@export var great_arc := deg_to_rad(12.0)
@export var warning_time := 0.7   # zone is shown, needle waits
@onready var click : AudioStreamPlayer = $"../../click"
var needle_speed := 3.0
var pos := 0.0
var zone_start := 0.0
var active := false
var checks_done := 0
var total_checks := 3
var _warmup := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()

func start_check(speed: float, done: int, total: int) -> void:
	needle_speed = speed
	checks_done = done
	total_checks = total
	zone_start = randf_range(PI * 0.6, TAU - good_arc - 0.2)
	pos = 0.0
	_warmup = warning_time
	active = true
	show()
	queue_redraw()

func _process(delta: float) -> void:
	if not active:
		return
	if _warmup > 0.0:
		_warmup -= delta
		return
	pos += needle_speed * delta
	if Input.is_action_just_pressed("skill_check"):
		click.play()
		_resolve()
	elif pos > zone_start + good_arc:
		_end("miss")
	queue_redraw()

func _resolve() -> void:
	if pos < zone_start:
		_end("miss")
	elif pos <= zone_start + good_arc:
		_end("great" if pos <= zone_start + great_arc else "good")
	else:
		_end("miss")

func _end(result: String) -> void:
	active = false
	hide()
	finished.emit(result)

func _draw() -> void:
	var c := size / 2.0
	var top := -PI / 2
	draw_arc(c, radius, 0, TAU, 64, Color(1, 1, 1, 0.25), 6.0)
	draw_arc(c, radius, top + zone_start, top + zone_start + good_arc, 24, Color.WHITE, 10.0)
	draw_arc(c, radius, top + zone_start, top + zone_start + great_arc, 12, Color.ORANGE_RED, 10.0)
	var dir := Vector2.from_angle(top + pos)
	draw_line(c + dir * (radius - 14), c + dir * (radius + 14), Color.RED, 4.0)
	for i in total_checks:
		var p := c + Vector2((i - (total_checks - 1) / 2.0) * 22.0, radius + 30)
		if i < checks_done:
			draw_circle(p, 7, Color.WHITE)
		else:
			draw_arc(p, 7, 0, TAU, 16, Color(1, 1, 1, 0.5), 2.0)
