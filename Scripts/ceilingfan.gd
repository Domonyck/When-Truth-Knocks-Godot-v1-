extends Area3D

@export var lights: Array[Node3D]
@onready var ceiliing_fan: AudioStreamPlayer = $CeiliingFan
@onready var fan_buzz_electrical_walmer_theatre_201162036: AudioStreamPlayer = $FanBuzzElectricalWalmerTheatre201162036

var is_on: bool = false

func _ready() -> void:
	_sync_state_from_lights()

func _process(_delta: float) -> void:
	_sync_state_from_lights()

func _sync_state_from_lights() -> void:
	var lights_actually_on := _get_lights_state()

	if lights_actually_on != is_on:
		is_on = lights_actually_on
		_apply_state()

func _get_lights_state() -> bool:
	for light in lights:
		if light and "visible" in light:
			return light.visible
	return is_on # fallback if no valid lights found

func _apply_state() -> void:
	for light in lights:
		if light and "visible" in light:
			light.visible = is_on

	if is_on:
		if not ceiliing_fan.playing:
			ceiliing_fan.play()
		if not fan_buzz_electrical_walmer_theatre_201162036.playing:
			fan_buzz_electrical_walmer_theatre_201162036.play()
	else:
		ceiliing_fan.stop()
		fan_buzz_electrical_walmer_theatre_201162036.stop()

func interact() -> void:
	is_on = not is_on
	_apply_state()

func force_shutdown() -> void:
	is_on = false
	_apply_state()
