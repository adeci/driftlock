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
		
		# Now we can safely set the global position
		player.global_position = RaceManager.get_spawn_position(spawn_id)
		
		# Get direction and calculate rotation
		var direction = RaceManager.get_spawn_direction(spawn_id)
		
		# Set player rotation
		player.global_rotation.y = RaceManager.get_spawn_rotation(spawn_id)
		
		# Set looking direction if available
		if player.has_method("set_looking_direction"):
			player.set_looking_direction(direction)
		elif "looking_direction" in player:
			player.looking_direction = direction
	
	print("Player " + str(peer_id) + " spawned at position: " + str(player.global_position))
	
	# IMPORTANT: Wait until after add_child to set global transforms
	if RaceManager.spawn_points.size() > 0:
		# For simplicity, use the first spawn point
		var spawn_id = RaceManager.spawn_points.keys()[0]
		
		# Assign this spawn point to the player for respawning too
		RaceManager.assign_spawn_to_player(peer_id, spawn_id)
		
		# Now we can safely set the global position
		player.global_position = RaceManager.get_spawn_position(spawn_id)
		
		# Set player rotation
		var rotation_y = RaceManager.get_spawn_rotation(spawn_id)
		player.global_rotation.y = rotation_y
		
		# If player has a looking_direction property, set it as well
		if player.has_method("set_looking_direction"):
			player.set_looking_direction(RaceManager.get_spawn_direction(spawn_id))
		elif "looking_direction" in player:
			player.looking_direction = RaceManager.get_spawn_direction(spawn_id)
	
	print("Player " + str(peer_id) + " spawned at position: " + str(player.global_position))


func remove_player_character(peer_id) -> void:
	var player = get_node(str(peer_id))
	remove_child(player)


func add_prev_connected_player():
	for peer_id in NetworkManager.lobby_members:
		add_player_character(peer_id, NetworkManager.lobby_members[peer_id])
