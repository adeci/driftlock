extends HBoxContainer


# Layer Radio ButtonsNodes
@export var layer_1: ButtonGroup

# Button Menus
@export var options_buttons: MarginContainer

# Reference Dictionary
@onready var menus: Dictionary = {
		"options_buttons": options_buttons,
}

# Race Conditions
var leave_pressed: bool = false


func _ready() -> void:
	NetworkManager.server_disconnected.connect(_on_leave_pressed)


func toggle_layer(_toggled_on:bool, layer_name: String):
	var layer_container = menus[layer_name]
	layer_container.visible = not layer_container.visible


func _on_layer_exit_pressed() -> void:
	var pressed_button := layer_1.get_pressed_button()
	pressed_button.button_pressed = false


func _on_leave_pressed() -> void:
	if not leave_pressed:
		leave_pressed = true
		NetworkManager.close_server()
		get_tree().change_scene_to_file("res://scenes/menus/menu.tscn")


func _on_resume_game_pressed() -> void:
	Input.action_press("PAUSE")
