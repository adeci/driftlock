extends MarginContainer


signal play_level(level: GameManager.Level)

@export var level_options: OptionButton
@export var play_button: Button

# Dynamic Menu Information
var worlds = "res://scenes/worlds/"
var levels = []

# Multiplayer Sync
var level_loaded := false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	multiplayer.server_disconnected.connect(_toggle_permissions.bind(false))
	
	## Load Debugging Levels
	#var dir = DirAccess.open(worlds)
	#if dir:
		#dir.list_dir_begin()
		#var file_name = dir.get_next()
		#while file_name != "":
			#if file_name.contains(".tscn"):
				#levels.append(file_name)
			#file_name = dir.get_next()
	#
	## Add Options
	#for level in levels:
		#level_options.add_item(level)


func _toggle_permissions(toggle: bool = false) -> void:
	level_options.disabled = toggle
	play_button.disabled = toggle


func _on_play_pressed() -> void:
	if multiplayer.is_server():
		var level = level_options.get_selected_id()
		NetworkManager.current_level = level
		play_level.emit(level)


func _on_lobby_menu_draw() -> void:
	if not multiplayer.is_server():
		_toggle_permissions(true)
