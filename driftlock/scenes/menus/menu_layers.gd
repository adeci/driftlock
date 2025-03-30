extends HBoxContainer


# Layer Radio ButtonsNodes
@export var layer_1: ButtonGroup

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
	exit.pressed.connect(_on_layer_exit_pressed)
	$Layer2/LevelSelectButtons/Buttons.add_child(exit)


func toggle_layer(toggled_on:bool, layer_name: String):
	var layer_container = menus[layer_name]
	layer_container.visible = not layer_container.visible


func _on_layer_exit_pressed() -> void:
	var pressed_button := layer_1.get_pressed_button()
	pressed_button.button_pressed = false


func _on_exit_pressed() -> void:
	get_tree().quit()
