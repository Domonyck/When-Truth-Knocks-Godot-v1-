extends Camera3D

@export var max_angle: float = 20.0 # Degrees of rotation for mouse look
@export var breath_amount: float = 0.03 # Vertical position offset for breathing (reduced)
@export var breath_speed: float = 1.8  # Slower, more natural breathing frequency
@export var idle_sway_amount: float = 0.3 # Subtle rotation sway when idle
@export var motion_sway_amount: float = 0.05 # Gentle lag/sway added when moving
@export var smooth_speed: float = 6.0 # Lower value for smoother, heavier inertia

var center_screen_position: Vector2
var time_passed: float = 0.0
var idle_timer: float = 0.0
var idle_threshold: float = 0.3 # Seconds before idle state takes over
var initial_position: Vector3

var target_rotation: Vector2 = Vector2.ZERO
var current_rotation: Vector2 = Vector2.ZERO
var mouse_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	center_screen_position = get_viewport().get_visible_rect().size / 2
	initial_position = position

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		idle_timer = 0.0 
		mouse_velocity = event.relative
		
		var mouse_pos = event.position
		var offset = (mouse_pos - center_screen_position) / center_screen_position
		
		target_rotation.y = -offset.x * max_angle
		target_rotation.x = -offset.y * max_angle

func _process(delta: float) -> void:
	idle_timer += delta
	time_passed += delta
	
	# Dampen mouse velocity smoothly to eliminate high-frequency shakes
	mouse_velocity = mouse_velocity.lerp(Vector2.ZERO, delta * 5.0)
	
	var final_rotation = target_rotation
	var target_pos_y = initial_position.y
	
	if idle_timer >= idle_threshold:
		# Slower, calmer idle breathing motion
		var breath = sin(time_passed * breath_speed) * breath_amount
		target_pos_y = initial_position.y + breath
		
		var idle_sway_y = sin(time_passed * (breath_speed * 0.5)) * idle_sway_amount
		var idle_sway_x = cos(time_passed * breath_speed) * (idle_sway_amount * 0.5)
		
		final_rotation.y += idle_sway_y
		final_rotation.x += idle_sway_x
	else:
		# Smooth motion lag instead of sharp jerks
		final_rotation.y -= mouse_velocity.x * motion_sway_amount
		final_rotation.x -= mouse_velocity.y * motion_sway_amount

	# Heavy interpolation for a fluid, weighted camera feel
	current_rotation.x = lerp(current_rotation.x, final_rotation.x, delta * smooth_speed)
	current_rotation.y = lerp(current_rotation.y, final_rotation.y, delta * smooth_speed)
	
	rotation_degrees.x = current_rotation.x
	rotation_degrees.y = current_rotation.y
	position.y = lerp(position.y, target_pos_y, delta * smooth_speed)
