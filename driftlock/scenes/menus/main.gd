extends Control

var multiplayer_peer = ENetMultiplayerPeer.new()

const PORT = 9999
var ADDRESS = "localhost" # Local for developemnt
var upnp = UPNP.new()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$GUI.visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if multiplayer_peer.get_unique_id() == 1:
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
	$World.add_player_character(2)

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
