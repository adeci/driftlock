extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_prev_connected_player(NetworkManager.lobby_members)
	NetworkManager.player_connected.connect(add_player_character)
	NetworkManager.player_disconnected.connect(remove_player_character)
	if NetworkManager.steam_status:
		if not NetworkManager.lobby_id:
			add_player_character(1, "Player")
	elif not NetworkManager.peer.ConnectionStatus:
		add_player_character(1, "Player")
		


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func add_player_character(peer_id, user_name = str(peer_id)) -> void:
	var player_character = preload("res://scenes/game_object/player_character.tscn").instantiate()
	player_character.set_multiplayer_authority(peer_id)
	player_character.name = str(peer_id)
	player_character.get_node("./Fox/Name").text = user_name
	add_child(player_character)


func remove_player_character(peer_id) -> void:
	var player_character = get_node(str(peer_id))
	remove_child(player_character)


func add_prev_connected_player(players: Dictionary):
	for peer_id in players:
		add_player_character(peer_id, players[peer_id])
