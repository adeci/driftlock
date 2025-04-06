extends Node3D


var player_character: PackedScene


func _init() -> void:
	player_character = preload("res://scenes/game_object/player_character.tscn")


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_prev_connected_player()
	NetworkManager.player_connected.connect(add_player_character)
	NetworkManager.player_disconnected.connect(remove_player_character)


func add_player_character(peer_id, user_name = str(peer_id)) -> void:
	var player = player_character.instantiate()
	player.set_multiplayer_authority(peer_id)
	player.name = str(peer_id)
	player.get_node("./Fox/Name").text = user_name
	add_child(player)


func remove_player_character(peer_id) -> void:
	var player = get_node(str(peer_id))
	remove_child(player)


func add_prev_connected_player():
	for peer_id in NetworkManager.lobby_members:
		add_player_character(peer_id, NetworkManager.lobby_members[peer_id])
