extends Node

# Network Signals
signal player_connected(peer_id: int, player_info: String)
signal player_disconnected(peer_id: int)
signal server_disconnected

# Network Handler
var peer: MultiplayerPeer
var steam_status := false

# Network Globals
const PORT: int = 9999
var address := "localhost"
var upnp = UPNP.new()
var lobby_id: int = 0
var owner_steam_id: int 

# Multiplayer Globals
var lobby_members: Dictionary = {}
var player_info := "Name"
var player_limit: int = 10
var lobby_type := Steam.LOBBY_TYPE_PUBLIC

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Set Network Handler
	steam_status = Steamworks.steam_status
	if steam_status:
		peer = SteamMultiplayerPeer.new()
		player_info = Steam.getPersonaName()
	else:
		peer = ENetMultiplayerPeer.new()
	
	# Set Multiplayer Signals
	multiplayer.peer_connected.connect(_on_player_connect)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnect)
	
	# Set Steam Signals
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_chat_update.connect(_on_lobby_chat_update)


# Called when node receives a notification
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and multiplayer.is_server():
		delete_ports()


# Auto Router Setup
func port_forward() -> void:
	
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
				address = external_ip


func delete_ports() -> void:
	upnp.delete_port_mapping(PORT, "UDP")
	upnp.delete_port_mapping(PORT, "TCP")


# Server/Client Creation
func create_server() -> void:
	if steam_status:
		peer.create_host(0)
		multiplayer.multiplayer_peer = peer
		Steam.createLobby(lobby_type, player_limit)
	else:
		port_forward()
		peer.create_server(PORT)
		multiplayer.multiplayer_peer = peer
	lobby_members[multiplayer.get_unique_id()] = player_info


func create_client(id: int = 0) -> void:
	if steam_status:
		Steam.joinLobby(id)
	else:
		peer.create_client(address, PORT)
		multiplayer.multiplayer_peer = peer
		lobby_members[multiplayer.get_unique_id()] = player_info


# Multiplayer Signals
func _on_player_connect(peer_id: int) -> void:
	_populate_lobby_members.rpc_id(peer_id, player_info)


@rpc("reliable", "any_peer")
func _populate_lobby_members(name: String) -> void:
	var peer_id = multiplayer.get_remote_sender_id()
	lobby_members[peer_id] = name
	player_connected.emit(peer_id, name)


func _on_player_disconnected(peer_id: int) -> void:
	lobby_members.erase(peer_id)
	player_disconnected.emit(peer_id)


func _on_connected_ok() -> void:
	pass


func _on_connected_failed() -> void:
	pass


func _on_server_disconnect() -> void:
	lobby_members.clear()
	lobby_id = 0
	owner_steam_id = 0
	server_disconnected.emit()


# Steam Signals
func _on_lobby_created(connect: int, this_lobby_id: int) -> void:
	if connect == 1:
		# Set the lobby ID
		lobby_id = this_lobby_id
		print("Created a lobby: %s" % lobby_id)
		
		# Set this lobby as joinable, just in case, though this should be done by default
		Steam.setLobbyJoinable(lobby_id, true)
		
		# Set some lobby data
		Steam.setLobbyData(lobby_id, "name", "Driftlock lobby")
		Steam.setLobbyData(lobby_id, "mode", "GodotSteam test")


func _on_lobby_joined(this_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		lobby_id = this_lobby_id
		owner_steam_id = Steam.getLobbyOwner(lobby_id)
		peer.create_client(owner_steam_id, 0)
		multiplayer.multiplayer_peer = peer
		lobby_members[multiplayer.get_unique_id()] = player_info


func _on_lobby_chat_update(this_lobby_id: int, change_id: int, making_change_id: int, chat_state: int) -> void:
	# Get the user who has made the lobby change
	var changer_name: String = Steam.getFriendPersonaName(change_id)
	
	# If a player has joined the lobby
	if chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_ENTERED:
		print("%s has joined the lobby." % changer_name)
	
	# Else if a player has left the lobby
	elif chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_LEFT:
		print("%s has left the lobby." % changer_name)
	
	# Else if a player has been kicked
	elif chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_KICKED:
		print("%s has been kicked from the lobby." % changer_name)
	
	# Else if a player has been banned
	elif chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_BANNED:
		print("%s has been banned from the lobby." % changer_name)
	
	else:
		print("%s did... something." % changer_name)
