extends Node

signal checkpoint_activated(checkpoint_id: int, player_id: int)
signal race_started(player_id: int)
signal race_completed(player_id: int, time: float)
signal all_checkpoints_cleared(player_id: int)
signal respawn_started(player_id: int)
signal respawn_complete(player_id: int)

var checkpoints: Dictionary = {} # Stores all checkpoint entities
var respawn_points: Dictionary = {} # Stores respawn points by checkpoint ID
var player_checkpoints: Dictionary = {} # Tracks which checkpoints each player has hit
var player_respawns: Dictionary = {} # Tracks respawn positions for each player
var player_respawn_rotations: Dictionary = {} # Tracks respawn rotations for each player
var player_race_times: Dictionary = {} # Tracks when each player started the race
var player_required_checkpoints: Dictionary = {} # Tracks required checkpoint count for each player
var player_respawning: Dictionary = {} # Tracks if a player is currently respawning

var spawn_points: Dictionary = {}

# Respawn settings
var respawn_hold_time: float = 2.0  # Seconds to hold player at respawn
var respawn_invincible_time: float = 5.0  # Seconds player is non-collidable after respawn

# Debug flag
var debug_mode: bool = true

func _ready() -> void:
	print("RaceManager initialized and ready")

# Register a spawn point with the manager
func register_spawn_point(spawn_id: int, position: Vector3, direction: Vector3, rotation_y: float = 0.0) -> void:
	spawn_points[spawn_id] = {
		"position": position,
		"direction": direction,
		"rotation_y": rotation_y
	}
	
	# Also set this as the initial respawn point for players
	if not player_respawns.has(spawn_id):
		player_respawns[spawn_id] = position
		player_respawn_rotations[spawn_id] = rotation_y

	if debug_mode:
		print("Registered spawn point for ID %d at position %s" % [spawn_id, position])

# Get a spawn position
func get_spawn_position(spawn_id: int = 1) -> Vector3:
	if spawn_points.has(spawn_id):
		return spawn_points[spawn_id]["position"]
	return Vector3.ZERO  # Default spawn if none set

# Get a spawn direction vector
func get_spawn_direction(spawn_id: int = 1) -> Vector3:
	if spawn_points.has(spawn_id):
		return spawn_points[spawn_id]["direction"]
	return Vector3(0, 0, 1)  # Default direction if none set

# Get a spawn rotation
func get_spawn_rotation(spawn_id: int = 1) -> float:
	if spawn_points.has(spawn_id):
		return spawn_points[spawn_id]["rotation_y"]
	return 0.0  # Default rotation if none set

# Assign a spawn point to a player
func assign_spawn_to_player(player_id: int, spawn_id: int = 1) -> void:
	if not spawn_points.has(spawn_id):
		if debug_mode:
			print("No spawn point with ID %d found for player %d" % [spawn_id, player_id])
		return
	
	# Make sure the player is registered
	if not player_checkpoints.has(player_id):
		register_player(player_id)
	
	# Set initial respawn point to the spawn point
	player_respawns[player_id] = spawn_points[spawn_id]["position"]
	player_respawn_rotations[player_id] = spawn_points[spawn_id]["rotation_y"]
	
	if debug_mode:
		print("Assigned player %d to spawn point %d at position %s" % [player_id, spawn_id, player_respawns[player_id]])

# Register a checkpoint with the manager
func register_checkpoint(checkpoint: Node, checkpoint_id: int, is_required: bool = true) -> void:
	checkpoints[checkpoint_id] = {
		"node": checkpoint,
		"required": is_required,
		"position": checkpoint.global_position
	}

	if debug_mode:
		print("Registered checkpoint %d at position %s (Required: %s)" % [checkpoint_id, checkpoint.global_position, is_required])

# Register a respawn point with the manager
func register_respawn_point(checkpoint_id: int, position: Vector3, rotation_y: float = 0.0, direction: Vector3 = Vector3.ZERO) -> void:
	respawn_points[checkpoint_id] = {
		"position": position,
		"rotation_y": rotation_y,
		"direction": direction
	}

	if debug_mode:
		print("Registered respawn point for checkpoint %d at position %s with direction %s" % 
		[checkpoint_id, position, direction])

# Register a player with the RaceManager
func register_player(player_id: int) -> void:
	if not player_checkpoints.has(player_id):
		player_checkpoints[player_id] = []
		player_race_times[player_id] = 0.0
		player_respawns[player_id] = Vector3.ZERO  # Default respawn
		player_respawn_rotations[player_id] = 0.0  # Default rotation
		player_respawning[player_id] = false

		# Count required checkpoints
		var required_count = 0
		for checkpoint_id in checkpoints:
			if checkpoints[checkpoint_id]["required"]:
				required_count += 1

		player_required_checkpoints[player_id] = required_count

		if debug_mode:
			print("Player %d registered with RaceManager. %d required checkpoints." % [player_id, required_count])

# Start a player's race and begin timing
func start_race(player_id: int) -> void:
	player_race_times[player_id] = Time.get_ticks_msec() / 1000.0
	emit_signal("race_started", player_id)

	if debug_mode:
		print("Race started for player %d" % player_id)

# Record a checkpoint being activated by a player
func activate_checkpoint(checkpoint_id: int, player_id: int, player_position: Vector3) -> void:
	if not player_checkpoints.has(player_id):
		register_player(player_id)

	# Check if this checkpoint has already been activated
	if checkpoint_id in player_checkpoints[player_id]:
		if debug_mode:
			print("Player %d already activated checkpoint %d" % [player_id, checkpoint_id])
		return

	# Record the checkpoint activation
	player_checkpoints[player_id].append(checkpoint_id)

	# If we have a custom respawn point for this checkpoint, use that
	if respawn_points.has(checkpoint_id):
		player_respawns[player_id] = respawn_points[checkpoint_id]["position"]
		player_respawn_rotations[player_id] = respawn_points[checkpoint_id]["rotation_y"]
		if debug_mode:
			print("Using custom respawn point for checkpoint %d" % checkpoint_id)
	else:
		# Otherwise use the player's current position
		player_respawns[player_id] = player_position
		if debug_mode:
			print("Using default respawn at player position for checkpoint %d" % checkpoint_id)

	# How many required checkpoints have been hit?
	var required_hit = 0
	for cp_id in player_checkpoints[player_id]:
		if checkpoints.has(cp_id) and checkpoints[cp_id]["required"]:
			required_hit += 1

	emit_signal("checkpoint_activated", checkpoint_id, player_id)

	if debug_mode:
		print("Player %d activated checkpoint %d. (%d/%d required checkpoints)" % 
		[player_id, checkpoint_id, required_hit, player_required_checkpoints[player_id]])

	# Check if all required checkpoints have been hit
	if required_hit >= player_required_checkpoints[player_id]:
		emit_signal("all_checkpoints_cleared", player_id)
		if debug_mode:
			print("Player %d has cleared all required checkpoints!" % player_id)

# Called when a player crosses the finish line
func finish_race(player_id: int) -> bool:
	if not player_checkpoints.has(player_id):
		if debug_mode:
			print("Player %d hasn't started the race!" % player_id)
		return false

	# Count how many required checkpoints the player has hit
	var required_hit = 0
	for cp_id in player_checkpoints[player_id]:
		if checkpoints.has(cp_id) and checkpoints[cp_id]["required"]:
			required_hit += 1

	# Check if the player has hit all required checkpoints
	if required_hit < player_required_checkpoints[player_id]:
		if debug_mode:
			print("Player %d needs to clear all checkpoints before finishing! (%d/%d)" % 
			[player_id, required_hit, player_required_checkpoints[player_id]])
		return false

	# Calculate race time
	var finish_time = Time.get_ticks_msec() / 1000.0
	var race_time = finish_time - player_race_times[player_id]

	emit_signal("race_completed", player_id, race_time)

	print("RACE COMPLETE! Player %d finished in %.2f seconds!" % [player_id, race_time])
	return true

# Start the respawn process for a player
func start_respawn(player_id: int) -> void:
	if player_respawning[player_id]:
		if debug_mode:
			print("Player %d is already respawning" % player_id)
		return

	if not player_respawns.has(player_id) or player_respawns[player_id] == Vector3.ZERO:
		if debug_mode:
			print("Player %d has no respawn point set" % player_id)
		return

	player_respawning[player_id] = true
	emit_signal("respawn_started", player_id)

	if debug_mode:
		print("Player %d starting respawn process" % player_id)

	# The actual respawn and post-respawn logic happens in the player controller

# Get the player's current respawn position
func get_respawn_position(player_id: int) -> Vector3:
	if player_respawns.has(player_id):
		return player_respawns[player_id]
	return Vector3.ZERO  # Default spawn if none set

# Get the player's current respawn rotation
func get_respawn_rotation(player_id: int) -> float:
	if player_respawn_rotations.has(player_id):
		return player_respawn_rotations[player_id]
	return 0.0  # Default rotation if none set

# Get respawn direction for a player
func get_respawn_direction(player_id: int) -> Vector3:
	# If we have a respawn position for this player
	if player_respawns.has(player_id):
		# Check if we have an entry in player_checkpoints for this player
		if player_checkpoints.has(player_id) and player_checkpoints[player_id].size() > 0:
			# The last checkpoint the player activated
			var last_checkpoint_id = player_checkpoints[player_id].back()
			
			# If we have direction data for this checkpoint
			if respawn_points.has(last_checkpoint_id) and respawn_points[last_checkpoint_id].has("direction"):
				return respawn_points[last_checkpoint_id]["direction"]
			
			# If we don't have direction data but have rotation, calculate it
			elif player_respawn_rotations.has(player_id):
				var rotation = player_respawn_rotations[player_id]
				return Vector3(sin(rotation), 0, cos(rotation))
	
	# Default direction (forward)
	return Vector3(0, 0, 1)

# Complete the respawn process
func complete_respawn(player_id: int) -> void:
	player_respawning[player_id] = false
	emit_signal("respawn_complete", player_id)

	if debug_mode:
		print("Player %d respawn complete" % player_id)

# Check if player is currently respawning
func is_player_respawning(player_id: int) -> bool:
	return player_respawning.get(player_id, false)

# Reset a player's race progress
func reset_player(player_id: int) -> void:
	player_checkpoints[player_id] = []
	player_race_times[player_id] = 0.0
	player_respawning[player_id] = false
	if debug_mode:
		print("Reset race progress for player %d" % player_id)

# Reset the entire race system
func reset_race() -> void:
	player_checkpoints.clear()
	player_race_times.clear()
	player_respawning.clear()
	if debug_mode:
		print("Race system reset")
