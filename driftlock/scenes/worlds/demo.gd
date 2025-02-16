extends Node3D

var multiplayer_peer = ENetMultiplayerPeer.new()

const PORT = 9999
const ADDRESS = "localhost" # Local for developemnt, TODO: Implement UPnP

var peer_ids = []

#TODO: Implement Multiplayer Menus

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func host() -> void:
	print("pressed")
	$Network/NetworkDisplay.text = "Server"
	$NetworkMenu.visible = false
	multiplayer_peer.create_server(PORT)
	multiplayer.multiplayer_peer = multiplayer_peer
	$Network/UniquePeerID.text = str(multiplayer.get_unique_id())
	
	multiplayer_peer.peer_connected.connect(
		func(new_peer_id):
			rpc("add_connected_player", new_peer_id)
			rpc_id(new_peer_id, "add_prev_connected_player", peer_ids)
			
			add_player_character(new_peer_id)
	)

func join() -> void:
	$Network/NetworkDisplay.text = "Client"
	$NetworkMenu.visible = false
	multiplayer_peer.create_client(ADDRESS, PORT)
	multiplayer.multiplayer_peer = multiplayer_peer
	$Network/UniquePeerID.text = str(multiplayer.get_unique_id())

func _on_NetworkMenu_clicked(tab: int) -> void:
	if(tab):
		join()
	else:
		host()

func add_player_character(peer_id) -> void:
	peer_ids.append(peer_id)
	var player_character = preload("res://scenes/game_object/player_character.tscn").instantiate()
	player_character.set_multiplayer_authority(peer_id)
	add_child(player_character)

@rpc
func add_connected_player(new_peer_id) -> void:
	add_player_character(new_peer_id)
	
@rpc
func add_prev_connected_player(peer_ids):
	for peer_id in peer_ids:
		add_player_character(peer_id)
