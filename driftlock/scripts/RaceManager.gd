extends Node

signal checkpoint_activated(checkpoint_id: int, player_id: int)
signal race_started(player_id: int)
signal race_completed(player_id: int, time: float)
signal all_checkpoints_cleared(player_id: int)
signal respawn_started(player_id: int)
signal respawn_complete(player_id: int)

var checkpoints: Dictionary = {}
var respawn_points: Dictionary = {}
var player_checkpoints: Dictionary = {}
var player_respawns: Dictionary = {}
var player_respawn_rotations: Dictionary = {}
var player_race_times: Dictionary = {}
var player_required_checkpoints: Dictionary = {}
var player_respawning: Dictionary = {}

var spawn_points: Dictionary = {}

# Respawn settings
var respawn_hold_time: float = 2.0
var respawn_invincible_time: float = 5.0

# Debug flag
var debug_mode: bool = true

func _ready() -> void:
	print("RaceManager initialized and ready")

func register_spawn_point(spawn_id: int, position: Vector3, direction: Vector3, rotation_y: float = 0.0) -> void:
	spawn_points[spawn_id] = {
		"position": position,
		"direction": direction,
		"rotation_y": rotation_y
	}
	if not player_respawns.has(spawn_id):
		player_respawns[spawn_id] = position
		player_respawn_rotations[spawn_id] = rotation_y
	if debug_mode:
		print("Registered spawn point for ID %d at position %s" % [spawn_id, position])

func get_spawn_position(spawn_id: int = 1) -> Vector3:
	if spawn_points.has(spawn_id):
		return spawn_points[spawn_id]["position"]
	return Vector3.ZERO

func get_spawn_direction(spawn_id: int = 1) -> Vector3:
	if spawn_points.has(spawn_id):
		return spawn_points[spawn_id]["direction"]
	return Vector3(0, 0, 1)

func get_spawn_rotation(spawn_id: int = 1) -> float:
	if spawn_points.has(spawn_id):
		return spawn_points[spawn_id]["rotation_y"]
	return 0.0

func assign_spawn_to_player(player_id: int, spawn_id: int = 1) -> void:
	if not spawn_points.has(spawn_id):
		if debug_mode:
			print("No spawn point with ID %d found for player %d" % [spawn_id, player_id])
		return
	if not player_checkpoints.has(player_id):
		register_player(player_id)
	player_respawns[player_id] = spawn_points[spawn_id]["position"]
	player_respawn_rotations[player_id] = spawn_points[spawn_id]["rotation_y"]
	if debug_mode:
		print("Assigned player %d to spawn point %d at position %s" % [player_id, spawn_id, player_respawns[player_id]])

func register_checkpoint(checkpoint: Node, checkpoint_id: int, is_required: bool = true) -> void:
	checkpoints[checkpoint_id] = {
		"node": checkpoint,
		"required": is_required,
		"position": checkpoint.global_position
	}
	if debug_mode:
		print("Registered checkpoint %d at position %s (Required: %s)" % [checkpoint_id, checkpoint.global_position, is_required])

func register_respawn_point(checkpoint_id: int, position: Vector3, rotation_y: float = 0.0, direction: Vector3 = Vector3.ZERO) -> void:
	respawn_points[checkpoint_id] = {
		"position": position,
		"rotation_y": rotation_y,
		"direction": direction
	}
	if debug_mode:
		print("Registered respawn point for checkpoint %d at position %s with direction %s" % 
		[checkpoint_id, position, direction])

func register_player(player_id: int) -> void:
	if not player_checkpoints.has(player_id):
		player_checkpoints[player_id] = []
		player_race_times[player_id] = 0.0
		player_respawns[player_id] = Vector3.ZERO
		player_respawn_rotations[player_id] = 0.0
		player_respawning[player_id] = false
		var required_count = 0
		for checkpoint_id in checkpoints:
			if checkpoints[checkpoint_id]["required"]:
				required_count += 1
		player_required_checkpoints[player_id] = required_count
		if debug_mode:
			print("Player %d registered with RaceManager. %d required checkpoints." % [player_id, required_count])

func start_race(player_id: int) -> void:
	player_race_times[player_id] = Time.get_ticks_msec() / 1000.0
	emit_signal("race_started", player_id)
	if debug_mode:
		print("Race started for player %d" % player_id)

func activate_checkpoint(checkpoint_id: int, player_id: int, player_position: Vector3) -> void:
	if not player_checkpoints.has(player_id):
		register_player(player_id)
	if checkpoint_id in player_checkpoints[player_id]:
		if debug_mode:
			print("Player %d already activated checkpoint %d" % [player_id, checkpoint_id])
		return
	player_checkpoints[player_id].append(checkpoint_id)
	if respawn_points.has(checkpoint_id):
		player_respawns[player_id] = respawn_points[checkpoint_id]["position"]
		player_respawn_rotations[player_id] = respawn_points[checkpoint_id]["rotation_y"]
		if debug_mode:
			print("Using custom respawn point for checkpoint %d" % checkpoint_id)
	else:
		player_respawns[player_id] = player_position
		if debug_mode:
			print("Using default respawn at player position for checkpoint %d" % checkpoint_id)
	var required_hit = 0
	for cp_id in player_checkpoints[player_id]:
		if checkpoints.has(cp_id) and checkpoints[cp_id]["required"]:
			required_hit += 1
	emit_signal("checkpoint_activated", checkpoint_id, player_id)
	if debug_mode:
		print("Player %d activated checkpoint %d. (%d/%d required checkpoints)" % 
		[player_id, checkpoint_id, required_hit, player_required_checkpoints[player_id]])
	if required_hit >= player_required_checkpoints[player_id]:
		emit_signal("all_checkpoints_cleared", player_id)
		if debug_mode:
			print("Player %d has cleared all required checkpoints!" % player_id)

func finish_race(player_id: int) -> bool:
	if not player_checkpoints.has(player_id):
		if debug_mode:
			print("Player %d hasn't started the race!" % player_id)
		return false
	var required_hit = 0
	for cp_id in player_checkpoints[player_id]:
		if checkpoints.has(cp_id) and checkpoints[cp_id]["required"]:
			required_hit += 1
	if required_hit < player_required_checkpoints[player_id]:
		if debug_mode:
			print("Player %d needs to clear all checkpoints before finishing! (%d/%d)" % 
			[player_id, required_hit, player_required_checkpoints[player_id]])
		return false
	var finish_time = Time.get_ticks_msec() / 1000.0
	var race_time = finish_time - player_race_times[player_id]
	emit_signal("race_completed", player_id, race_time)
	print("RACE COMPLETE! Player %d finished in %.2f seconds!" % [player_id, race_time])
	return true

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
func get_respawn_position(player_id: int) -> Vector3:
	if player_respawns.has(player_id):
		return player_respawns[player_id]
	return Vector3.ZERO

func get_respawn_rotation(player_id: int) -> float:
	if player_respawn_rotations.has(player_id):
		return player_respawn_rotations[player_id]
	return 0.0  # Default rotation if none set

func get_respawn_direction(player_id: int) -> Vector3:
	if player_respawns.has(player_id):
		if player_checkpoints.has(player_id) and player_checkpoints[player_id].size() > 0:
			var last_checkpoint_id = player_checkpoints[player_id].back()
			if respawn_points.has(last_checkpoint_id) and respawn_points[last_checkpoint_id].has("direction"):
				return respawn_points[last_checkpoint_id]["direction"]
			elif player_respawn_rotations.has(player_id):
				var rotation = player_respawn_rotations[player_id]
				return Vector3(sin(rotation), 0, cos(rotation))
	return Vector3(0, 0, 1)

func complete_respawn(player_id: int) -> void:
	player_respawning[player_id] = false
	emit_signal("respawn_complete", player_id)
	if debug_mode:
		print("Player %d respawn complete" % player_id)

func is_player_respawning(player_id: int) -> bool:
	return player_respawning.get(player_id, false)

func reset_player(player_id: int) -> void:
	player_checkpoints[player_id] = []
	player_race_times[player_id] = 0.0
	player_respawning[player_id] = false
	if debug_mode:
		print("Reset race progress for player %d" % player_id)

func reset_race() -> void:
	player_checkpoints.clear()
	player_race_times.clear()
	player_respawning.clear()
	if debug_mode:
		print("Race system reset")


func reset_race_manager() -> void:
	player_checkpoints.clear()
	checkpoints.clear()
	respawn_points.clear()
	player_required_checkpoints.clear()
	player_race_times.clear()
	player_respawning.clear()
	player_respawns.clear()
	player_respawn_rotations.clear()
	spawn_points.clear()
	if debug_mode:
		print("Race system reset")
