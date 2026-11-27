extends AudioStreamPlayer

@export var light_manager: Node      # Drag your scene's LightManager node here
@export var lightning_light: Node    # Drag LightningLight from SubViewport here

@export_group("Storm Timing")
@export var min_strike_interval: float = 35.0
@export var max_strike_interval: float = 55.0
@export var thunder_delays: Array[float] = [1.0, 3.0, 4.0]

@export_group("Blackout Integration")
## 0.0 = never causes blackout, 0.5 = 50% chance, 1.0 = always causes blackout
@export_range(0.0, 1.0) var blackout_chance: float = 0.3

var _is_striking: bool = false

func _ready() -> void:
	add_to_group("thunder") 
	if is_instance_valid(lightning_light) and "visible" in lightning_light:
		lightning_light.visible = false

	light_manager = _find_valid_light_manager()
	_storm_loop()

func reset_state() -> void:
	_is_striking = false
	stop()                      # cut any thunder that is playing
	if is_instance_valid(lightning_light) and "visible" in lightning_light:
		lightning_light.visible = false

func _find_valid_light_manager() -> Node:
	if is_instance_valid(light_manager):
		return light_manager

	# Find the LightManager instance that actually has the room light areas assigned
	for node in get_tree().get_nodes_in_group("light_manager"):
		if node.get("ceiling_fan_area") != null or node.get("wall_lamp_area") != null or node.get("office_assets_area") != null:
			return node

	return get_tree().get_first_node_in_group("light_manager")

func _unhandled_input(event: InputEvent) -> void:
	# DEBUG: Press L to test a lightning strike immediately
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L:
		_trigger_lightning_strike()

func _storm_loop() -> void:
	while is_inside_tree():
		var wait_time := randf_range(min_strike_interval, max_strike_interval)
		await get_tree().create_timer(wait_time).timeout
		if not is_inside_tree():
			return

		await _trigger_lightning_strike()

func _trigger_lightning_strike() -> void:
	if _is_striking:
		return
	_is_striking = true

	# 1. Flash the lightning light FIRST (while silent)
	await _flash_lightning()
	if not is_inside_tree():
		_is_striking = false
		return

	# 2. Trigger the full brownout/blackout (shuts off all lights, PC, and enables generator)
	light_manager = _find_valid_light_manager()
	if is_instance_valid(light_manager):
		if not light_manager.is_blackout and randf() <= blackout_chance:
			light_manager.force_blackout()
	else:
		push_warning("ThunderPlayer: No LightManager found in scene!")

	# 3. Wait 1, 3, or 4 seconds after the flash before playing thunder
	var sound_delay: float = thunder_delays.pick_random()
	await get_tree().create_timer(sound_delay).timeout
	if not is_inside_tree():
		_is_striking = false
		return

	# 4. Play the thunder sound
	pitch_scale = randf_range(0.9, 1.1)
	play()
	_is_striking = false

func _flash_lightning() -> void:
	if not is_instance_valid(lightning_light) or not ("visible" in lightning_light):
		return

	lightning_light.visible = true
	await get_tree().create_timer(0.08).timeout
	if not is_instance_valid(lightning_light) or not is_inside_tree():
		return

	lightning_light.visible = false
	await get_tree().create_timer(0.06).timeout
	if not is_instance_valid(lightning_light) or not is_inside_tree():
		return

	lightning_light.visible = true
	await get_tree().create_timer(0.12).timeout
	if not is_instance_valid(lightning_light) or not is_inside_tree():
		return

	lightning_light.visible = false
