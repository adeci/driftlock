extends MarginContainer


var host_ready: bool = false


# Called before the scene is loaded
func _init() -> void:
	tree_entered.connect(func(): NetworkManager.current_level = -1)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	NetworkManager.load_level.connect(remote_play)
	NetworkManager.server_disconnected.connect(_on_lobby_exit_pressed)
	$LobbyMenu/ElementSeperator/SettingsMenu/LobbySettingButtons.play_level.connect(_on_start_level)
	
	SoundManager.play_music(SoundManager.SoundCatalog.MENU_MUSIC, false)
	
	if (NetworkManager.lobby_id):
		$LobbyMenu.visible = true
	else:
		$MainMenu.visible = true
		$LobbyMenu.visible = false
	$HostPopup.visible = false
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
	$LobbyLoading.visible = true
	await NetworkManager.avatar_loaded
	$LobbyLoading.visible = false
	$LobbyMenu.visible = true


func _on_lobby_exit_pressed() -> void:
	NetworkManager.close_server()
	$LobbyMenu.visible = false
	$LobbyLoading.visible = false
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

func _on_volume_settings_pressed() -> void:
	VolumeControl.show_control()
	SoundManager.play_sound(SoundManager.SoundCatalog.BUTTON1)

func _on_start_level(level_name) -> void:
	$MainMenu.visible = false
	$HostPopup.visible = false
	$LobbyMenu.visible = false
	$LobbyList.visible = false
	$SampleUIElements.visible = false
	SoundManager.cleanup_level_sounds()
	RaceManager.reset_race_manager()
	var packed_scene: PackedScene
	match level_name:
		GameManager.Level.DEMO:
			packed_scene = preload("res://scenes/Levels/demo_level.tscn")
		GameManager.Level.BEACH:
			packed_scene = preload("res://scenes/Levels/beachzone_level.tscn")
		GameManager.Level.DUNGEON:
			packed_scene = preload("res://scenes/Levels/dungeon_level.tscn")
	if multiplayer.is_server():
		remote_play.rpc(NetworkManager.current_level)
	get_tree().paused = true
	get_tree().change_scene_to_packed(packed_scene)


@rpc("reliable")
func remote_play(level: GameManager.Level) -> void:
	NetworkManager.current_level = level
	_on_start_level(level)
