extends HBoxContainer

# Layer Nodes
@export var layer_1: MarginContainer
@export var layer_2: MarginContainer
@export var layer_3: MarginContainer

# Button Menus
@export var level_select: MarginContainer 
@export var multiplayer_buttons: MarginContainer
@export var options_buttons: MarginContainer

# Dynamic Menu Information
var worlds = "res://scenes/worlds/"
var levels = []

# Reference Dictionary
@onready var menus: Dictionary = {
		"level_select": level_select,
		"multiplayer_buttons": multiplayer_buttons,
		"options_buttons": options_buttons,
}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Load Debugging Levels
	var dir = DirAccess.open(worlds)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.contains(".tscn"):
				levels.append(file_name)
			file_name = dir.get_next()
	
	# Add Level Select Buttons
	var exit = $%SampleUIElements/Exit.duplicate()
	for level in levels:
		var level_button = exit.duplicate()
		level_button.text = level
		$Layer2/LevelSelectButtons/Buttons.add_child(level_button)
	$Layer2/LevelSelectButtons/Buttons.add_child(exit)


func toggle_layer(toggled_on:bool, layer_name: String):
	var layer_container = menus[layer_name]
	layer_container.visible = not layer_container.visible


func _on_exit_pressed() -> void:
	get_tree().quit()
