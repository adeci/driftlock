extends Node

# Network Signals
signal player_connected(peer_id: int, player_info: String)
signal load_level(level: GameManager.Level)
signal player_disconnected(peer_id: int)
signal avatar_loaded
signal server_disconnected
signal ping(peer_id: int, ping: int)

# Network Handler
var peer: MultiplayerPeer
var steam_status := false

# Network Globals
var PORT: int = 9999
var address := "localhost"
var upnp = UPNP.new()
var lobby_id: int = 0
var owner_steam_id: int 
var current_level: int = -1
var local: bool = false
var upnp_enabled: bool = true
var thread: Thread = null
var prev_time_msec: int = 0

# Multiplayer Globals
var lobby_members: Dictionary = {}
var player_information: Dictionary = {}
var player_ping: Dictionary = {}
var player_info := "Name"
var player_limit: int = 10
var lobby_type := Steam.LOBBY_TYPE_PUBLIC
var lobby_name := "Driftlock"
var lobby_mode := "Arcade"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	
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
	ping.connect(_set_ping)
	
	# Set Steam Signals
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_chat_update.connect(_on_lobby_chat_update)
	Steam.avatar_loaded.connect(_on_loaded_avatar)


func _exit_tree() -> void:
	if thread:
		thread.wait_to_finish()


# Called when node receives a notification
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and multiplayer.is_server() and not steam_status:
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
		Steam.getPlayerAvatar()
		lobby_members[multiplayer.get_unique_id()] = player_info
	else:
		if upnp_enabled:
			thread = Thread.new()
			thread.start(port_forward)
		peer.create_server(PORT)
		multiplayer.multiplayer_peer = peer
		lobby_id = 1
		player_information[multiplayer.get_unique_id()] = TextureRect.new()
		lobby_members[multiplayer.get_unique_id()] = player_info
		avatar_loaded.emit()


func create_client(id: int = 0) -> void:
	if steam_status:
		Steam.joinLobby(id)
		await multiplayer.connected_to_server
		Steam.getPlayerAvatar()
	else:
		peer.create_client(address, PORT)
		multiplayer.multiplayer_peer = peer
		lobby_id = 1
		player_information[multiplayer.get_unique_id()] = TextureRect.new()
		lobby_members[multiplayer.get_unique_id()] = player_info


func create_local(level: GameManager.Level) -> void:
	var local_peer = ENetMultiplayerPeer.new()
	local_peer.create_server(PORT)
	multiplayer.multiplayer_peer = local_peer
	lobby_members[multiplayer.get_unique_id()] = player_info
	local = true
	_sync_level(level)


# Close Server
func close_server() -> void:
	multiplayer.multiplayer_peer.close()
	if steam_status:
		Steam.leaveLobby(lobby_id)
	lobby_members.clear()
	player_information.clear()
	lobby_id = 0
	owner_steam_id = 0
	current_level = -1
	SoundManager.cleanup_level_sounds()
	if local:
		local = false


func get_ping() -> void:
	prev_time_msec = Time.get_ticks_msec()
	ping_remote.rpc()


func _set_ping(peer_id: int, ping: int):
	player_ping[peer_id] = ping


@rpc("reliable")
func ping_remote() -> void:
	return_ping.rpc_id(multiplayer.get_remote_sender_id())


@rpc("reliable", "any_peer")
func return_ping() -> void:
	ping.emit(multiplayer.get_remote_sender_id(), Time.get_ticks_msec() - prev_time_msec)


# Multiplayer Signals
func _on_player_connect(peer_id: int) -> void:
	_populate_lobby_members.rpc_id(peer_id, player_info)
	if multiplayer.is_server() and current_level > -1:
		_sync_level.rpc_id(peer_id, current_level)


@rpc("reliable", "any_peer")
func _populate_lobby_members(player_name: String) -> void:
	var peer_id = multiplayer.get_remote_sender_id()
	lobby_members[peer_id] = player_name
	if steam_status:
		Steam.getPlayerAvatar(2, peer.get_steam64_from_peer_id(peer_id))
		await avatar_loaded
	else:
		player_information[peer_id] = TextureRect.new()
	player_connected.emit(peer_id, player_name)

@rpc("reliable")
func _sync_level(level: GameManager.Level) -> void:
	current_level = level
	load_level.emit(level)


func _on_player_disconnected(peer_id: int) -> void:
	lobby_members.erase(peer_id)
	player_information.erase(peer_id)
	player_disconnected.emit(peer_id)


func _on_connected_ok() -> void:
	pass


func _on_connected_failed() -> void:
	server_disconnected.emit()


func _on_server_disconnect() -> void:
	if steam_status:
		Steam.leaveLobby(lobby_id)
	lobby_members.clear()
	lobby_id = 0
	owner_steam_id = 0
	server_disconnected.emit()


# Steam Signals
func _on_lobby_created(connect_status: int, this_lobby_id: int) -> void:
	if connect_status == 1:
		# Set the lobby ID
		lobby_id = this_lobby_id
		print("Created a lobby: %s" % lobby_id)
		
		# Set this lobby as joinable, just in case, though this should be done by default
		Steam.setLobbyJoinable(lobby_id, true)
		
		# Set some lobby data
		Steam.setLobbyData(lobby_id, "name", lobby_name)
		Steam.setLobbyData(lobby_id, "mode", lobby_mode)


func _on_lobby_joined(this_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		lobby_id = this_lobby_id
		owner_steam_id = Steam.getLobbyOwner(lobby_id)
		if owner_steam_id != Steam.getSteamID():
			peer.create_client(owner_steam_id, 0)
			multiplayer.multiplayer_peer = peer
			lobby_members[multiplayer.get_unique_id()] = player_info


# Steam Signal Functions
func _on_loaded_avatar(user_id: int, avatar_size: int, avatar_buffer: PackedByteArray) -> void:
	# Create Image
	var avatar_image := Image.create_from_data(avatar_size, avatar_size, false, Image.FORMAT_RGBA8, avatar_buffer)
	
	# Resize Image
	if avatar_size > 64:
		avatar_image.resize(64, 64, Image.INTERPOLATE_LANCZOS)
	
	# Create texture
	var new_peer_id: int = NetworkManager.peer.get_peer_id_from_steam64(user_id)
	player_information[new_peer_id] = ImageTexture.create_from_image(avatar_image)
	avatar_loaded.emit()


func _on_lobby_chat_update(_this_lobby_id: int, change_id: int, _making_change_id: int, chat_state: int) -> void:
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
