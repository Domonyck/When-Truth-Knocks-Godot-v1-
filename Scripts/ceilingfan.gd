extends Area3D

@export var lights: Array[Node3D]
@onready var ceiling_fan: AudioStreamPlayer = $CeiliingFan
@onready var fan_buzz: AudioStreamPlayer = $FanBuzzElectricalWalmerTheatre201162036

var is_on: bool = true 

func _ready() -> void:
	for light in lights:
		if light and "visible" in light:
			light.visible = true
			if light.has_signal("visibility_changed"):
				light.visibility_changed.connect(_on_light_visibility_changed)

	if not fan_buzz.playing:
		fan_buzz.play()

func interact() -> void:
	is_on = not is_on
	ceiling_fan.play()
	_apply_state()

func force_shutdown() -> void:
	is_on = false
	_apply_state()

func _apply_state() -> void:
	for light in lights:
		if light and "visible" in light:
			light.visible = is_on

	if is_on:
		if not fan_buzz.playing:
			fan_buzz.play()
	else:
		fan_buzz.stop()

func _on_light_visibility_changed() -> void:
	var lights_actually_on := false
	for light in lights:
		if light and "visible" in light and light.visible:
			lights_actually_on = true
			break

	if is_on != lights_actually_on:
		is_on = lights_actually_on
		_apply_state()
