extends Node2D

@export_group("Monitored Light Nodes")
@export var ceiling_fan_area: Area3D
@export var wall_lamp_area: Area3D
@export var office_assets_area: Area3D

@export_group("Target Dependencies")
@export var mesh_instance_2: MeshInstance3D
@export var computer2: Area3D

@export_group("Light Cutout Settings")
@export var cutout_chance_per_frame: float = 0.001 

func _ready() -> void:
	randomize()
	# Ensure light manager continues running while game is paused in desktop scene
	process_mode = Node.PROCESS_MODE_ALWAYS
	_update_power_state()

func _process(_delta: float) -> void:
	_process_random_cutout()
	# Continuously evaluate power state so turning lights back on updates immediately
	_update_power_state()

func _process_random_cutout() -> void:
	var areas = [ceiling_fan_area, wall_lamp_area, office_assets_area]
	
	for area in areas:
		if is_area_light_on(area):
			if randf() < cutout_chance_per_frame:
				_turn_off_area_lights(area)

func _turn_off_area_lights(area: Area3D) -> void:
	if area == null:
		return
		
	if "lights" in area:
		for light in area.lights:
			if is_instance_valid(light) and "visible" in light:
				light.visible = false

	for child in area.get_children():
		if child is Light3D:
			child.visible = false

# Call this helper function from your light switch/repair mechanics to turn an area's lights back on
func turn_on_area_lights(area: Area3D) -> void:
	if area == null:
		return

	if "lights" in area:
		for light in area.lights:
			if is_instance_valid(light) and "visible" in light:
				light.visible = true

	for child in area.get_children():
		if child is Light3D:
			child.visible = true

func is_area_light_on(area: Area3D) -> bool:
	if area == null:
		return false

	if "lights" in area:
		for light in area.lights:
			if is_instance_valid(light) and "visible" in light and light.visible:
				return true

	for child in area.get_children():
		if child is Light3D and child.visible:
			return true

	return false

func _update_power_state() -> void:
	var ceiling_on = is_area_light_on(ceiling_fan_area)
	var wall_on = is_area_light_on(wall_lamp_area)
	var office_on = is_area_light_on(office_assets_area)

	# Power is active if AT LEAST ONE area light is turned on
	var has_power = ceiling_on or wall_on or office_on

	if has_power:
		# INSTANTLY restore computer screen and interaction capability
		if is_instance_valid(mesh_instance_2) and not mesh_instance_2.visible:
			mesh_instance_2.visible = true

		if is_instance_valid(computer2):
			if not computer2.is_powered:
				computer2.is_powered = true
			for child in computer2.get_children():
				if (child is CollisionShape3D or child is CollisionPolygon3D) and child.disabled:
					child.disabled = false
	else:
		# TOTAL BLACKOUT: Turn off computer screen and boot player out of desktop overlay
		if is_instance_valid(mesh_instance_2) and mesh_instance_2.visible:
			mesh_instance_2.visible = false

		if is_instance_valid(computer2):
			if computer2.is_powered:
				computer2.is_powered = false
			
			if computer2.is_desktop_open:
				computer2.force_shutdown_desktop()
				
			for child in computer2.get_children():
				if (child is CollisionShape3D or child is CollisionPolygon3D) and not child.disabled:
					child.disabled = true
