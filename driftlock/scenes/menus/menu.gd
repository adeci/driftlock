extends MarginContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	NetworkManager.server_disconnected.connect(_on_lobby_exit_pressed)
	$LobbyMenu/ElementSeperator/SettingsMenu/LobbySettingButtons.play_level.connect(_on_start_level)
	$MainMenu.visible = true
	$HostPopup.visible = false
	$LobbyMenu.visible = false
	$LobbyLoading.visible = false
	$LobbyList.visible = false
	$SampleUIElements.visible = false


func _on_host_pressed() -> void:
	$MainMenu.visible = false
	if NetworkManager.steam_status:
		$HostPopup/HostButtonsContainerENet.visible = false
	else:
		$HostPopup/HostButtonsContainerSteam.visible = false
	$HostPopup.visible = true


func _on_host_exit_pressed() -> void:
	$HostPopup.visible = false
	$MainMenu.visible = true


func _on_create_lobby_pressed() -> void:
	$HostPopup.visible = false
	$LobbyMenu.visible = true


func _on_lobby_exit_pressed() -> void:
	NetworkManager.close_server()
	$LobbyMenu.visible = false
	$MainMenu.visible = true


func _on_lobby_list_exit_pressed() -> void:
	$LobbyList.visible = false
	$MainMenu.visible = true


func _on_join_pressed() -> void:
	$LobbyList.visible = true
	$MainMenu.visible = false


func _on_lobby_button_pressed() -> void:
	$LobbyList.visible = false
	$LobbyLoading.visible = true
	await NetworkManager.player_connected
	$LobbyLoading.visible = false
	$LobbyMenu.visible = true


func _on_start_level(level_name) -> void:
	$MainMenu.visible = false
	$HostPopup.visible = false
	$LobbyMenu.visible = false
	$LobbyList.visible = false
	$SampleUIElements.visible = false
	match level_name:
		GameManager.Level.DEMO:
			get_tree().change_scene_to_file("res://scenes/worlds/demo_level.tscn")
		GameManager.Level.BEACH:
			get_tree().change_scene_to_file("res://scenes/worlds/beachzone_level.tscn")
