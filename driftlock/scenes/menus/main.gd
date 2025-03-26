extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$GUI.visible = false
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	NetworkManager.server_disconnected.connect(_on_server_disconnect)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func host() -> void:
	$GUI.visible = true
	if not NetworkManager.steam_status:
		NetworkManager.player_info = $MainMenu/Host/Name.text
	$GUI/Network/NetworkDisplay.text = "Server"
	NetworkManager.create_server()
	$GUI/Network/UniquePeerID.text = str(multiplayer.get_unique_id())
	$World.add_player_character(1, NetworkManager.player_info)
	multiplayer.peer_connected.connect(send_level)



func join() -> void:
	if Steamworks.steam_status:
		Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_CLOSE)
		Steam.requestLobbyList()
	else:
		$GUI.visible = true
		$GUI/Network/NetworkDisplay.text = "CLIENT"
		NetworkManager.player_info = $MainMenu/Join/Name.text
		NetworkManager.create_client()
		await multiplayer.connected_to_server
		$GUI/Network/UniquePeerID.text = str(multiplayer.get_unique_id())


func single() -> void:
	$World.add_player_character(1)


func _on_lobby_match_list(these_lobbies: Array) -> void:
	for this_lobby in these_lobbies:
		
		# Pull lobby data from Steam, these are specific to our example
		var lobby_name: String = Steam.getLobbyData(this_lobby, "name")
		var lobby_mode: String = Steam.getLobbyData(this_lobby, "mode")
		
		# Get the current number of members
		var lobby_num_members: int = Steam.getNumLobbyMembers(this_lobby)
		
		# Create a button for the lobby
		var lobby_button: Button = Button.new()
		lobby_button.set_text("Lobby %s: %s [%s] - %s Player(s)" % [this_lobby, lobby_name, lobby_mode, lobby_num_members])
		lobby_button.set_size(Vector2(800, 50))
		lobby_button.set_name("lobby_%s" % this_lobby)
		lobby_button.pressed.connect(join_lobby.bind(this_lobby))
		
		# Add the new lobby to the list
		$MainMenu/Lobbies/List.add_child(lobby_button)


func join_lobby(this_lobby: int) -> void:
	$MainMenu/Lobbies.visible = false
	$GUI.visible = true
	NetworkManager.create_client(this_lobby)
	await multiplayer.connected_to_server
	$GUI/Network/NetworkDisplay.text = "CLIENT"
	$GUI/Network/UniquePeerID.text = str(NetworkManager.peer.get_unique_id())


func _on_server_disconnect() -> void:
	get_tree().quit()


func send_level(peer_id: int):
	load_level.rpc_id(peer_id, $World.scene_file_path)


@rpc("reliable")
func load_level(level_path):
	var level = load(level_path).instantiate()
	add_child(level)
