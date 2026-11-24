
extends Camera3D

@export_group("Wobble Settings")
@export var wobble_enabled: bool = true
@export var wobble_position: float = 0.035
@export var wobble_rotation: float = 0.8
@export var wobble_speed: float = 1.0

@export_group("Movement Settings")
@export var vertical_bob: float = 0.025
@export var horizontal_sway: float = 0.015

var initial_position: Vector3
var initial_rotation: Vector3
var elapsed_time: float = 0.0

func _ready() -> void:
	initial_position = position
	initial_rotation = rotation

func _process(delta: float) -> void:
	if not wobble_enabled:
		return

	elapsed_time += delta * wobble_speed

	# Smooth floating movement
	var vertical = sin(elapsed_time * 1.5) * vertical_bob
	var horizontal = cos(elapsed_time * 0.8) * horizontal_sway

	# Subtle random-like camera wobble
	var wobble_x = sin(elapsed_time * 2.0) * wobble_position
	var wobble_y = cos(elapsed_time * 1.7) * wobble_position

	# Apply position
	position = initial_position + Vector3(
		horizontal + wobble_x,
		vertical + wobble_y,
		0.0
	)

	# Apply rotation
	rotation = initial_rotation + Vector3(
		sin(elapsed_time * 1.2) * deg_to_rad(wobble_rotation),
		cos(elapsed_time * 0.9) * deg_to_rad(wobble_rotation),
		sin(elapsed_time * 0.7) * deg_to_rad(wobble_rotation * 0.5)
	)
