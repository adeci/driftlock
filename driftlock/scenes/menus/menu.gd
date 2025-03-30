extends MarginContainer


var level

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	NetworkManager.server_disconnected.connect(_on_lobby_exit_pressed)
	$LobbyMenu/ElementSeperator/SettingsMenu/LobbySettingButtons.play_level.connect(_on_start_level)
	$MainMenu.visible = true
	$HostPopup.visible = false
	$LobbyMenu.visible = false
	$LobbyList.visible = false
	$SampleUIElements.visible = false


func _on_host_pressed() -> void:
	$MainMenu.visible = false
	$HostPopup.visible = true


func _on_host_exit_pressed() -> void:
	$HostPopup.visible = false
	$MainMenu.visible = true


func _on_create_lobby_pressed() -> void:
	$HostPopup.visible = false
	$LobbyMenu.visible = true


func _on_lobby_exit_pressed() -> void:
	NetworkManager.close_server()
	self.remove_child(level)
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
	$LobbyMenu.visible = true


func _on_start_level(file_path: String) -> void:
	$MainMenu.visible = false
	$HostPopup.visible = false
	$LobbyMenu.visible = false
	$LobbyList.visible = false
	$SampleUIElements.visible = false
	level = load(file_path).instantiate()
	add_child(level)
