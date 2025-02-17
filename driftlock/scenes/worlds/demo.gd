extends Node3D

var multiplayer_peer = ENetMultiplayerPeer.new()

const PORT = 9999
var ADDRESS = "localhost" # Local for developemnt, TODO: Implement UPnP

var peer_ids = []

#TODO: Implement Multiplayer Menus

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func port_forward() -> void:
	$Network/ExternalIP.text = "FAILED"
	
	var upnp = UPNP.new()
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
				$Network/ExternalIP.text = str(ADDRESS)

func host() -> void:
	port_forward()
	
	$Network/NetworkDisplay.text = "Server"
	$NetworkMenu.visible = false
	multiplayer_peer.create_server(PORT)
	multiplayer.multiplayer_peer = multiplayer_peer
	$Network/UniquePeerID.text = str(multiplayer.get_unique_id())
	
	add_player_character(1)
	
	multiplayer_peer.peer_connected.connect(
		func(new_peer_id):
			rpc_id(new_peer_id, "add_prev_connected_player", peer_ids)
			rpc("add_player_character", new_peer_id)
			
			add_player_character(new_peer_id)
	)
	
	multiplayer_peer.peer_disconnected.connect(
		func(old_peer_id):
			rpc("remove_player_character", old_peer_id)
			
			remove_player_character(old_peer_id)
	)

func join() -> void:
	$Network/NetworkDisplay.text = "Client"
	$NetworkMenu.visible = false
	$IPAddress.visible = true
	await $IPAddress.text_submitted
	$IPAddress.visible = false
	if not $IPAddress.text == "":
		ADDRESS = $IPAddress.text
	multiplayer_peer.create_client(ADDRESS, PORT)
	multiplayer.multiplayer_peer = multiplayer_peer
	$Network/UniquePeerID.text = str(multiplayer.get_unique_id())
	
	multiplayer.server_disconnected.connect(
		func():
			get_tree().quit()
	)

func _on_NetworkMenu_clicked(tab: int) -> void:
	if(tab):
		join()
	else:
		host()

@rpc
func add_player_character(peer_id) -> void:
	peer_ids.append(peer_id)
	var player_character = preload("res://scenes/game_object/player_character.tscn").instantiate()
	player_character.set_multiplayer_authority(peer_id)
	player_character.name = str(peer_id)
	add_child(player_character)

@rpc("reliable")
func remove_player_character(peer_id) -> void:
	peer_ids.erase(peer_id)
	remove_child(get_node(str(peer_id)))

@rpc
func add_prev_connected_player(peer_ids):
	for peer_id in peer_ids:
		add_player_character(peer_id)
