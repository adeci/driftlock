extends Control

var steam_peer = SteamMultiplayerPeer.new()
var multiplayer_peer = ENetMultiplayerPeer.new()

var steam_status: bool = true
const PORT = 9999
var ADDRESS = "localhost" # Local for developemnt
var upnp = UPNP.new()

#Steam Constants
var lobby_id: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$GUI.visible = false
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_match_list.connect(_on_lobby_match_list)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if multiplayer_peer.get_unique_id() == 1 && not steam_status:
				delete_ports()
		get_tree().quit()

func port_forward() -> void:
	$GUI/Network/ExternalIP.text = "FAILED"
	
	var discover_result = upnp.discover()
	
	if discover_result == UPNP.UPNP_RESULT_SUCCESS:
		if upnp.get_gateway() and upnp.get_gateway().is_valid_gateway():
			
			var map_result_udp = upnp.add_port_mapping(PORT, PORT, "driftlock_udp", "UDP", 0)
			var map_result_tcp = upnp.add_port_mapping(PORT, PORT, "driftlock_tcp", "TCP", 0)
			
			if not map_result_udp == UPNP.UPNP_RESULT_SUCCESS:
				map_result_udp = upnp.add_port_mapping(PORT, PORT, "", "UDP")
			if not map_result_tcp == UPNP.UPNP_RESULT_SUCCESS:
				map_result_tcp = upnp.add_port_mapping(PORT, PORT, "", "TCP")
			if map_result_udp == UPNP.UPNP_RESULT_SUCCESS && map_result_tcp == UPNP.UPNP_RESULT_SUCCESS:
				var external_ip = upnp.query_external_address()
				ADDRESS = external_ip
				$GUI/Network/ExternalIP.text = str(ADDRESS)


func delete_ports() -> void:
	upnp.delete_port_mapping(9999, "UDP")
	upnp.delete_port_mapping(9999, "TCP")


func host() -> void:
	if steam_status:
		steam_peer.create_host(0)
		multiplayer.multiplayer_peer = steam_peer
		Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, 10)
	else:
		$GUI.visible = true
		port_forward()
		
		$GUI/Network/NetworkDisplay.text = "Server"
		multiplayer_peer.create_server(PORT)
		multiplayer.multiplayer_peer = multiplayer_peer
		$GUI/Network/UniquePeerID.text = str(multiplayer.get_unique_id())
		
		$World.add_player_character(1, $MainMenu/Host/Name.text)
		
		multiplayer_peer.peer_connected.connect(
			func(new_peer_id):
				rpc_id(new_peer_id, "load_level", $World.scene_file_path)
				$World.rpc_id(new_peer_id, "add_prev_connected_player", $World.peer_ids, $World.names)
				$World.rpc("add_player_character", new_peer_id)
				
				$World.add_player_character(new_peer_id)
				
				rpc_id(new_peer_id, "add_player_character", new_peer_id)
		)


		multiplayer_peer.peer_disconnected.connect(
			func(old_peer_id):
				$World.rpc("remove_player_character", old_peer_id)
				
				$World.remove_player_character(old_peer_id)
		)


func join() -> void:
	if steam_status:
		Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_CLOSE)
		Steam.requestLobbyList()
	else:
		$GUI.visible = true
		multiplayer_peer.create_client(ADDRESS, PORT)
		multiplayer.multiplayer_peer = multiplayer_peer
		$GUI/Network/NetworkDisplay.text = "CLIENT"
		$GUI/Network/UniquePeerID.text = str(multiplayer_peer.get_unique_id())
		
		multiplayer.server_disconnected.connect(
			func():
				get_tree().quit()
		)

func single() -> void:
	$World.add_player_character(1)

func _on_lobby_created(connect: int, this_lobby_id: int) -> void:
	if connect == 1:
		# Set the lobby ID
		lobby_id = this_lobby_id
		print("Created a lobby: %s" % lobby_id)
		
		# Set this lobby as joinable, just in case, though this should be done by default
		Steam.setLobbyJoinable(lobby_id, false)
		
		# Set some lobby data
		Steam.setLobbyData(lobby_id, "name", "Driftlock lobby")
		Steam.setLobbyData(lobby_id, "mode", "GodotSteam test")

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
		lobby_button.connect("pressed", Callable(self, "join_lobby").bind(this_lobby))
		
		# Add the new lobby to the list
		$MainMenu/Lobbies/List.add_child(lobby_button)

func join_lobby() -> void:
	pass

@rpc
func add_player_character(peer_id):
	var player_character = $World.get_node(str(peer_id))
	player_character.get_child(0).get_child(3).text = $MainMenu/Join/Name.text
	rpc("set_user_name", peer_id, $MainMenu/Join/Name.text)

@rpc("reliable")
func load_level(level_path):
	var level = load(level_path).instantiate()
	add_child(level)

@rpc("any_peer")
func set_user_name(peer_id, user):
	var player_character = $World.get_node(str(peer_id))
	player_character.get_child(0).get_child(3).text = user
	$World.names.erase(str(peer_id))
	$World.names.append(user)
