extends Node3D

signal scene_loaded

@export_file("*.tscn") var target_scene_path: String = "res://MainRoom.tscn"
@export var camera: Camera3D # Optional: auto-detects the active Camera3D if left empty

var _loading: bool = false
var _loaded_scene: PackedScene = null

func _ready() -> void:
	if not camera:
		camera = get_viewport().get_camera_3d()

	if camera and camera.has_signal("thunder_started"):
		camera.thunder_started.connect(_on_thunder_started)

func _on_thunder_started() -> void:
	start_loading(target_scene_path)

func start_loading(path: String) -> void:
	if path != "" and not _loading and _loaded_scene == null:
		target_scene_path = path
		ResourceLoader.load_threaded_request(target_scene_path)
		_loading = true

func _process(_delta: float) -> void:
	if not _loading:
		return

	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(target_scene_path, progress)

	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_loading = false
		_loaded_scene = ResourceLoader.load_threaded_get(target_scene_path)
		scene_loaded.emit()
		get_tree().change_scene_to_packed(_loaded_scene)

	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		_loading = false
		push_error("Failed to threaded-load scene: " + target_scene_path)
		_loaded_scene = load(target_scene_path)
		if _loaded_scene:
			get_tree().change_scene_to_packed(_loaded_scene)
