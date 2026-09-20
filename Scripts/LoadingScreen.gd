extends Control

signal scene_loaded

@export_file("*.tscn") var target_scene_path: String = "res://MainRoom.tscn"

@onready var status_label: Label = $UIContainer/StatusLabel
@onready var progress_label: Label = $UIContainer/ProgressLabel

var loading: bool = false
var loaded_scene: PackedScene = null

func _ready() -> void:
	# Automatically start loading when the scene opens
	start_loading(target_scene_path)

func start_loading(path: String) -> void:
	if path != "":
		target_scene_path = path
		status_label.text = "Loading..."
		progress_label.text = "0%"
		ResourceLoader.load_threaded_request(target_scene_path)
		loading = true

func _process(_delta: float) -> void:
	if not loading:
		return

	var progress: Array = []
	var status = ResourceLoader.load_threaded_get_status(target_scene_path, progress)

	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		if progress.size() > 0:
			var percentage: int = int(progress[0] * 100)
			progress_label.text = str(percentage) + "%"

	elif status == ResourceLoader.THREAD_LOAD_LOADED:
		progress_label.text = "100%"
		status_label.text = "Complete!"
		loading = false
		
		loaded_scene = ResourceLoader.load_threaded_get(target_scene_path)
		scene_loaded.emit()
		
		# Change to the loaded scene
		get_tree().change_scene_to_packed(loaded_scene)

	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		status_label.text = "Failed to Load"
		loading = false
