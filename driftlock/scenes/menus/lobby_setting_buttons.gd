extends MarginContainer


signal play_level(file_path: String)

@export var level_options: OptionButton
@export var play_button: Button

# Dynamic Menu Information
var worlds = "res://scenes/worlds/"
var levels = []

# Multiplayer Sync
var level_loaded := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	multiplayer.connected_to_server.connect(_toggle_permissions)
	multiplayer.server_disconnected.connect(_toggle_permissions)
	NetworkManager.load_level.connect(remote_play)
	
	# Load Debugging Levels
	var dir = DirAccess.open(worlds)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.contains(".tscn"):
				levels.append(file_name)
			file_name = dir.get_next()
	
	# Add Options
	for level in levels:
		level_options.add_item(level)


func _toggle_permissions() -> void:
	level_options.disabled = not level_options.disabled
	play_button.disabled = not play_button.disabled


func _on_play_pressed() -> void:
	if multiplayer.is_server():
		NetworkManager.current_level = level_options.get_selected_id()
		play_level.emit(worlds+levels[level_options.get_selected_id()])
		remote_play.rpc(level_options.get_selected_id())


@rpc("reliable")
func remote_play(id: int) -> void:
	play_level.emit(worlds+levels[id])
