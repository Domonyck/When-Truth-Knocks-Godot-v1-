extends Camera3D
 
@export var max_angle: float = 20.0 
@export var breath_amount: float = 0.03 
@export var breath_speed: float = 1.8  
@export var idle_sway_amount: float = 0.3 
@export var motion_sway_amount: float = 0.05 
@export var smooth_speed: float = 6.0 
@export var focus_speed: float = 4.0 # Speed at which the camera snaps to the character
 
var center_screen_position: Vector2
var time_passed: float = 0.0
var idle_timer: float = 0.0
var idle_threshold: float = 0.3 
var initial_position: Vector3
 
var target_rotation: Vector2 = Vector2.ZERO
var current_rotation: Vector2 = Vector2.ZERO
var mouse_velocity: Vector2 = Vector2.ZERO

# NEW: Tracking variables for the 2.5D sprite
var focus_target: Node3D = null
var focus_offset: Vector3 = Vector3(0, 1.2, 0) # Offsets the gaze to their face instead of their feet
 
func _ready() -> void:
	add_to_group("player_camera")
	center_screen_position = get_viewport().get_visible_rect().size / 2
	initial_position = position

# NEW: Call these to lock/unlock the camera
func lock_on_target(target: Node3D) -> void:
	focus_target = target

func unlock_camera() -> void:
	focus_target = null
 
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		idle_timer = 0.0 
		mouse_velocity = event.relative
		
		# Only update mouse target rotation if we aren't locked onto a character
		if focus_target == null:
			var mouse_pos = event.position
			var offset = (mouse_pos - center_screen_position) / center_screen_position
			
			target_rotation.y = -offset.x * max_angle
			target_rotation.x = -offset.y * max_angle
		
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		try_interact_at_mouse()
 
func try_interact_at_mouse() -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = project_ray_origin(mouse_pos)
	var ray_end = ray_origin + project_ray_normal(mouse_pos) * 1000.0
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collision_mask = 7
	query.collide_with_areas = true 
	
	var result = space_state.intersect_ray(query)
	if result:
		var collider = result.collider
		if collider is Area3D and collider.has_method("interact"):
			collider.interact()
 
func _process(delta: float) -> void:
	idle_timer += delta
	time_passed += delta
	
	mouse_velocity = mouse_velocity.lerp(Vector2.ZERO, delta * 5.0)
	var target_pos_y = initial_position.y
	
	if focus_target != null:
		# 1. Look directly at the character's face
		var look_target_pos = focus_target.global_position + focus_offset
		var temp_transform = global_transform.looking_at(look_target_pos, Vector3.UP)
		
		# 2. Extract the euler angles required to face them
		var target_euler = temp_transform.basis.get_euler()
		var target_deg = Vector2(rad_to_deg(target_euler.x), rad_to_deg(target_euler.y))
		
		# 3. Lerp rotation directly to the character
		current_rotation.x = lerp(current_rotation.x, target_deg.x, delta * focus_speed)
		current_rotation.y = lerp(current_rotation.y, target_deg.y, delta * focus_speed)
		
		# 4. Sync mouse target so it doesn't snap wildly when you unlock the camera
		target_rotation = current_rotation
		
		# Maintain natural breathing while locked on
		target_pos_y = initial_position.y + (sin(time_passed * breath_speed) * breath_amount)
		
	else:
		# 5. ORIGINAL MOUSE SWAY LOGIC
		var final_rotation = target_rotation
		
		if idle_timer >= idle_threshold:
			target_pos_y = initial_position.y + (sin(time_passed * breath_speed) * breath_amount)
			final_rotation.y += sin(time_passed * (breath_speed * 0.5)) * idle_sway_amount
			final_rotation.x += cos(time_passed * breath_speed) * (idle_sway_amount * 0.5)
		else:
			final_rotation.y -= mouse_velocity.x * motion_sway_amount
			final_rotation.x -= mouse_velocity.y * motion_sway_amount
			
		current_rotation.x = lerp(current_rotation.x, final_rotation.x, delta * smooth_speed)
		current_rotation.y = lerp(current_rotation.y, final_rotation.y, delta * smooth_speed)
 
	rotation_degrees.x = current_rotation.x
	rotation_degrees.y = current_rotation.y
	position.y = lerp(position.y, target_pos_y, delta * smooth_speed)
