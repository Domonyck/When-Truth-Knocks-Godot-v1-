extends Node2D

@export_group("Monitored Light Nodes")
@export var ceiling_fan_area: Area3D
@export var wall_lamp_area: Area3D
@export var office_assets_area: Area3D
@onready var night_ambience_29548: AudioStreamPlayer = $NightAmbience29548
@onready var gen_off: AudioStreamPlayer = $SubViewportContainer/SubViewport/door/Area3D/GeneratorOff

@export_group("Target Dependencies")
@export var mesh_instance_2: MeshInstance3D
@export var computer2: Area3D

@export_group("Light Cutout Settings")
@export var cutout_chance_per_second: float = 0.02 
@export var in_computer_multiplier: float = 3.5

signal blackout_started
signal power_restored

var is_blackout := false

func _ready() -> void:
	randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_update_power_state()
	night_ambience_29548.play()

func _process(delta: float) -> void:
	if not is_blackout:
		_process_random_cutout(delta)
	
	_update_power_state()

func _process_random_cutout(delta: float) -> void:
	var areas = [ceiling_fan_area, wall_lamp_area, office_assets_area]
	
	var current_chance = cutout_chance_per_second
	if is_instance_valid(computer2) and computer2.is_desktop_open:
		current_chance *= in_computer_multiplier
	
	for area in areas:
		if is_area_light_on(area):
			if randf() < (current_chance * delta):
				_turn_off_area_lights(area)
				# When a light randomly turns off, make IT interactable so the player can fix/turn it back on
				_set_area_interactable(area, true)

func _unhandled_input(event: InputEvent) -> void:
	# DEBUG: press B to force a blackout
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
		force_blackout()

func force_blackout() -> void:
	if is_blackout:
		return
		
	is_blackout = true
	blackout_started.emit()
	
	for area in [ceiling_fan_area, wall_lamp_area, office_assets_area]:
		if is_instance_valid(gen_off):
			gen_off.play()
		_turn_off_area_lights(area)
		
		# FORCE BLACKOUT: Keep lights UNINTERACTABLE as requested
		_set_area_interactable(area, false)

	# Update environmental assets/computer for blackout mode
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

func _set_area_interactable(area: Area3D, enabled: bool) -> void:
	if area == null:
		return
	area.input_ray_pickable = enabled
	for child in area.get_children():
		if child is CollisionShape3D or child is CollisionPolygon3D:
			child.set_deferred("disabled", not enabled)

func restore_power() -> void:
	for area in [ceiling_fan_area, wall_lamp_area, office_assets_area]:
		_set_area_interactable(area, true)
		turn_on_area_lights(area)
		
	is_blackout = false
	
	if is_instance_valid(mesh_instance_2) and not mesh_instance_2.visible:
		mesh_instance_2.visible = true

	if is_instance_valid(computer2):
		if not computer2.is_powered:
			computer2.is_powered = true
		for child in computer2.get_children():
			if (child is CollisionShape3D or child is CollisionPolygon3D) and child.disabled:
				child.disabled = false
				
	power_restored.emit()
	
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
	# Check if at least one monitored area still has its lights on
	var ceiling_on = is_area_light_on(ceiling_fan_area)
	var wall_on = is_area_light_on(wall_lamp_area)
	var office_on = is_area_light_on(office_assets_area)

	var has_power = ceiling_on or wall_on or office_on

	# If we are in a forced blackout, we keep the blackout rules enforced
	if is_blackout:
		return

	# Handle regular state changes based on individual light statuses
	if has_power:
		if is_instance_valid(mesh_instance_2) and not mesh_instance_2.visible:
			mesh_instance_2.visible = true

		if is_instance_valid(computer2):
			if not computer2.is_powered:
				computer2.is_powered = true
			for child in computer2.get_children():
				if (child is CollisionShape3D or child is CollisionPolygon3D) and child.disabled:
					child.disabled = false
	else:
		# If all individual lights randomly turn off, hide mesh_instance_2 too
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
