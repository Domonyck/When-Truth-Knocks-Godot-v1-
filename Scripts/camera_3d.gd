extends Camera3D
 
@export var max_angle: float = 20.0 
@export var breath_amount: float = 0.03 
@export var breath_speed: float = 1.8  
@export var idle_sway_amount: float = 0.3 
@export var motion_sway_amount: float = 0.05 
@export var smooth_speed: float = 6.0 
 
var center_screen_position: Vector2
var time_passed: float = 0.0
var idle_timer: float = 0.0
var idle_threshold: float = 0.3 
var initial_position: Vector3
 
var target_rotation: Vector2 = Vector2.ZERO
var current_rotation: Vector2 = Vector2.ZERO
var mouse_velocity: Vector2 = Vector2.ZERO
 
func _ready() -> void:
	add_to_group("player_camera")
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
		
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		try_interact_at_mouse()
 
func try_interact_at_mouse() -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Project a 3D ray from the camera lens through the mouse cursor position
	var ray_origin = project_ray_origin(mouse_pos)
	var ray_end = ray_origin + project_ray_normal(mouse_pos) * 1000.0
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collision_mask = 7 # Layers 1, 2, and 3
	query.collide_with_areas = true 
	
	var result = space_state.intersect_ray(query)
	if result:
		var collider = result.collider
		print("Clicked on: ", collider.name)
		if collider is Area3D and collider.has_method("interact"):
			collider.interact()
		else:
			print("Hit object is an Area3D, but lacks an interact() method.")
	else:
		print("Raycast from mouse hit nothing.")
 
func _process(delta: float) -> void:
	idle_timer += delta
	time_passed += delta
	
	mouse_velocity = mouse_velocity.lerp(Vector2.ZERO, delta * 5.0)
	
	var final_rotation = target_rotation
	var target_pos_y = initial_position.y
	
	if idle_timer >= idle_threshold:
		var breath = sin(time_passed * breath_speed) * breath_amount
		target_pos_y = initial_position.y + breath
		
		var idle_sway_y = sin(time_passed * (breath_speed * 0.5)) * idle_sway_amount
		var idle_sway_x = cos(time_passed * breath_speed) * (idle_sway_amount * 0.5)
		
		final_rotation.y += idle_sway_y
		final_rotation.x += idle_sway_x
	else:
		final_rotation.y -= mouse_velocity.x * motion_sway_amount
		final_rotation.x -= mouse_velocity.y * motion_sway_amount
 
	current_rotation.x = lerp(current_rotation.x, final_rotation.x, delta * smooth_speed)
	current_rotation.y = lerp(current_rotation.y, final_rotation.y, delta * smooth_speed)
	
	rotation_degrees.x = current_rotation.x
	rotation_degrees.y = current_rotation.y
	position.y = lerp(position.y, target_pos_y, delta * smooth_speed)
 
