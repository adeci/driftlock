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
var leave_pressed: bool = false
var scene_lock: int = 0: set = lock


func _ready() -> void:
	NetworkManager.server_disconnected.connect(_on_leave_pressed)
	options_buttons.visible = false

func toggle_layer(_toggled_on:bool, layer_name: String):
	var layer_container = menus[layer_name]
	layer_container.visible = not layer_container.visible


func lock(num: int) -> void:
	scene_lock = num
	if scene_lock == NetworkManager.lobby_members.size():
		_on_exit_clock_timeout()


func _on_volume_settings_pressed() -> void:
	VolumeControl.show_control()
	SoundManager.play_sound(SoundManager.SoundCatalog.BUTTON1)


func _on_layer_exit_pressed() -> void:
	var pressed_button := layer_1.get_pressed_button()
	if pressed_button:
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
	get_tree().create_timer(30, true).timeout.connect(_on_exit_clock_timeout)
	NetworkManager.player_disconnected.connect(lock.bind(scene_lock))
	SoundManager.cleanup_level_sounds()
	RaceManager.reset_race_manager()
	remote_suspend.rpc()
	peer_ready()


func _on_exit_clock_timeout() -> void:
	to_main.rpc()
	get_tree().change_scene_to_file("res://scenes/menus/menu.tscn")


@rpc("reliable", "any_peer")
func peer_ready() -> void:
	scene_lock += 1


@rpc("reliable")
func remote_suspend() -> void:
	get_tree().paused = true
	peer_ready.rpc_id(1)


@rpc("reliable")
func to_main() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/menu.tscn")
