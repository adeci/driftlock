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
	
	# First add the player to the scene tree
	add_child(player)
	
	# IMPORTANT: Wait until after add_child to set global transforms
	if RaceManager.spawn_points.size() > 0:
		# For simplicity, use the first spawn point
		var spawn_id = RaceManager.spawn_points.keys()[0]
		
		# Assign this spawn point to the player for respawning too
		RaceManager.assign_spawn_to_player(peer_id, spawn_id)
		
		# Get transformation data from RaceManager
		var spawn_position = RaceManager.get_spawn_position(spawn_id)
		var spawn_direction = RaceManager.get_spawn_direction(spawn_id)
		var spawn_rotation = RaceManager.get_spawn_rotation(spawn_id)
		
		# Set player transforms
		player.global_position = spawn_position
		player.global_rotation.y = spawn_rotation
		
		var fox = player.get_node("Fox")
		if fox:
			# Set the looking_direction property
			if "looking_direction" in fox:
				fox.looking_direction = spawn_direction
				print("Set looking_direction on Fox: " + str(spawn_direction))
			
			# Or use the method if available
			elif fox.has_method("set_looking_direction"):
				fox.set_looking_direction(spawn_direction)
				print("Called set_looking_direction on Fox")
		
		print("Player " + str(peer_id) + " spawned at position: " + str(spawn_position) + " with rotation: " + str(spawn_rotation))
	else:
		print("No spawn points found. Using default spawn position.")


func remove_player_character(peer_id) -> void:
	var player = get_node(str(peer_id))
	remove_child(player)


func add_prev_connected_player():
	for peer_id in NetworkManager.lobby_members:
		add_player_character(peer_id, NetworkManager.lobby_members[peer_id])
