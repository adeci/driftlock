extends Node3D

var peer_ids = []
var names = []


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


@rpc
func add_player_character(peer_id, user_name = str(peer_id)) -> void:
	peer_ids.append(peer_id)
	if not names.find(user_name) == -1:
		user_name = str(peer_id)
	names.append(user_name)
	var player_character = preload("res://scenes/game_object/player_character.tscn").instantiate()
	player_character.set_multiplayer_authority(peer_id)
	player_character.name = str(peer_id)
	player_character.get_child(0).get_child(3).text = user_name
	add_child(player_character)

@rpc("reliable")
func remove_player_character(peer_id) -> void:
	var player_character = get_node(str(peer_id))
	names.erase(str(player_character.get_child(0).get_child(3).text))
	peer_ids.erase(peer_id)
	remove_child(player_character)

@rpc
func add_prev_connected_player(rpc_peer_ids, rpc_names):
	for index in range(rpc_peer_ids.size()):
		add_player_character(rpc_peer_ids[index], rpc_names[index])
