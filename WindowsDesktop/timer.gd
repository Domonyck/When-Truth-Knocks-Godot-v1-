extends Panel

@onready var clock_label: Label = $Label

func _process(delta: float) -> void:
	if GameManager:
		# Calculate the current hour directly from the global GameManager state
		var current_hour = int(GameManager.real_time_passed / GameManager.REAL_SECONDS_PER_GAME_HOUR)
		
		var display_hour = current_hour % 12
		if display_hour == 0:
			display_hour = 12
			
		var period = "AM" if current_hour < 12 else "PM"
		
		if current_hour >= 6:
			if clock_label:
				clock_label.text = "6:00 AM"
			return
			
		if clock_label:
			clock_label.text = "%d:00 %s" % [display_hour, period]

func hide_time() -> void:
	visible = false 

func show_time() -> void:
	visible = true
