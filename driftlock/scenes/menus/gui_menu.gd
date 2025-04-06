extends HBoxContainer


# Layer Radio ButtonsNodes
@export var layer_1: ButtonGroup

# Button Menus
@export var options_buttons: MarginContainer

# Reference Dictionary
@onready var menus: Dictionary = {
		"options_buttons": options_buttons,
}


func toggle_layer(_toggled_on:bool, layer_name: String):
	var layer_container = menus[layer_name]
	layer_container.visible = not layer_container.visible


func _on_layer_exit_pressed() -> void:
	var pressed_button := layer_1.get_pressed_button()
	pressed_button.button_pressed = false


func _on_leave_pressed() -> void:
	NetworkManager.close_server()


func _on_resume_game_pressed() -> void:
	Input.action_press("PAUSE")
