extends HBoxContainer


signal exit_to_lobby


# Layer Radio ButtonsNodes
@export var layer_1: ButtonGroup

# Button Menus
@export var options_buttons: MarginContainer

# Reference Dictionary
@onready var menus: Dictionary = {
		"options_buttons": options_buttons,
}

# Race Conditions
var exit_clock: SceneTreeTimer = null
var leave_pressed: bool = false
var ready_count: int = 0
var scene_lock: bool = false:
	get:
		ready_count += 1
		if ready_count == NetworkManager.lobby_members.size() - 1:
			ready_count = 0
			return true
		else: return false


func _ready() -> void:
	NetworkManager.server_disconnected.connect(_on_leave_pressed)
	exit_clock = get_tree().create_timer(30, true) # Force exit condition
	exit_clock.timeout.connect(_on_exit_clock_timeout)


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


func _on_exit_to_lobby_pressed() -> void:
	get_tree().paused = true
	exit_clock.start()
	remote_suspend.rpc()
	if NetworkManager.lobby_members.size() == 1:
		get_tree().change_scene_to_file("res://scenes/menus/menu.tscn")


func _on_exit_clock_timeout() -> void:
	to_main.rpc()
	get_tree().change_scene_to_file("res://scenes/menus/menu.tscn")


@rpc("reliable", "any_peer")
func peer_ready() -> void:
	if scene_lock:
		to_main.rpc()
		get_tree().change_scene_to_file("res://scenes/menus/menu.tscn")


@rpc("reliable")
func remote_suspend() -> void:
	get_tree().paused = true
	peer_ready.rpc_id(1)


@rpc("reliable")
func to_main() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/menu.tscn")
