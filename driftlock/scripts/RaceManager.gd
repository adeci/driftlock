@tool
extends Node

signal checkpoint_activated(checkpoint_id: int, player_id: int)
signal race_started(player_id: int)
signal race_completed(player_id: int, time: float)
signal all_checkpoints_cleared(player_id: int)
signal respawn_started(player_id: int)
signal respawn_complete(player_id: int)
signal lap_completed(player_id: int, lap_number: int)
signal race_won(player_id: int, total_time: float, lap_count: int)

var checkpoints: Dictionary = {}
var respawn_points: Dictionary = {}
var player_checkpoints: Dictionary = {}
var player_respawns: Dictionary = {}
var player_respawn_rotations: Dictionary = {}
var player_race_times: Dictionary = {}
var player_required_checkpoints: Dictionary = {}
var player_respawning: Dictionary = {}

var player_final_times: Dictionary = {}
signal all_race_times_received(times: Dictionary)

var spawn_points: Dictionary = {}

# Respawn settings
var respawn_hold_time: float = 2.0
var respawn_invincible_time: float = 5.0

var auto_start_race: bool = true
var player_ready_to_race: Dictionary = {}
var player_current_lap: Dictionary = {}
var player_completed_laps: Dictionary = {}
var required_laps: int = 3 

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
		player_ready_to_race[player_id] = false  # New field
		
		player_current_lap[player_id] = 1
		player_completed_laps[player_id] = 0
		
		var required_count = 0
		for checkpoint_id in checkpoints:
			if checkpoints[checkpoint_id]["required"]:
				required_count += 1
		player_required_checkpoints[player_id] = required_count
		
		if debug_mode:
			print("Player %d registered with RaceManager. %d required checkpoints." % [player_id, required_count])
		
		if auto_start_race:
			player_ready_to_race[player_id] = true


func player_spawned(player_id: int) -> void:
	if auto_start_race and player_ready_to_race.get(player_id, false) and not race_started_helper(player_id):
		start_race(player_id)
		if debug_mode:
			print("Automatically started race for player %d" % player_id)

func race_started_helper(player_id: int) -> bool:
	return player_race_times.has(player_id) and player_race_times[player_id] > 0.0

func start_race(player_id: int) -> void:
	player_race_times[player_id] = Time.get_ticks_msec() / 1000.0
	emit_signal("race_started", player_id)
	if debug_mode:
		print("Race started for player %d" % player_id)
	if player_id == multiplayer.get_unique_id():
		SoundManager.play_sound(SoundManager.SoundCatalog.GO)

func activate_checkpoint(checkpoint_id: int, player_id: int, player_position: Vector3) -> void:
	if not player_checkpoints.has(player_id):
		register_player(player_id)
	if debug_mode:
		print("Attempting to activate checkpoint %d for player %d in lap %d" % 
			  [checkpoint_id, player_id, player_current_lap.get(player_id, 1)])
		print("Current checkpoints: %s" % str(player_checkpoints[player_id]))
	if checkpoint_id in player_checkpoints[player_id]:
		if debug_mode:
			print("Player %d already activated checkpoint %d in this lap" % [player_id, checkpoint_id])
		return
	if not player_checkpoints.has(player_id):
		player_checkpoints[player_id] = []
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
		print("Player %d activated checkpoint %d in lap %d. (%d/%d required checkpoints)" % 
		[player_id, checkpoint_id, player_current_lap.get(player_id, 1), required_hit, player_required_checkpoints.get(player_id, 0)])
	if required_hit >= player_required_checkpoints.get(player_id, 0):
		emit_signal("all_checkpoints_cleared", player_id)
		if debug_mode:
			print("Player %d has cleared all required checkpoints for lap %d!" % 
				 [player_id, player_current_lap.get(player_id, 1)])

func finish_race(player_id: int) -> bool:
	if not player_checkpoints.has(player_id):
		if debug_mode:
			print("Player %d hasn't started the race!" % player_id)
		return false
	if debug_mode:
		print("Player %d crossed finish line in lap %d with checkpoints: %s" % 
			  [player_id, player_current_lap.get(player_id, 1), str(player_checkpoints[player_id])])
	var required_hit = 0
	for cp_id in player_checkpoints[player_id]:
		if checkpoints.has(cp_id) and checkpoints[cp_id]["required"]:
			required_hit += 1
	if debug_mode:
		print("Player %d has hit %d/%d required checkpoints in lap %d" % 
			  [player_id, required_hit, player_required_checkpoints.get(player_id, 0), 
			   player_current_lap.get(player_id, 1)])
	if required_hit < player_required_checkpoints.get(player_id, 0):
		if debug_mode:
			print("Player %d needs to clear all checkpoints before finishing! (%d/%d)" % 
			[player_id, required_hit, player_required_checkpoints.get(player_id, 0)])
		return false
	player_completed_laps[player_id] += 1
	var lap_number = player_completed_laps[player_id]
	if debug_mode:
		print("Player %d completed lap %d" % [player_id, lap_number])
	emit_signal("lap_completed", player_id, lap_number)
	if lap_number >= required_laps:
		var finish_time = Time.get_ticks_msec() / 1000.0
		var race_time = finish_time - player_race_times[player_id]
		record_final_time(player_id, race_time)
		emit_signal("race_won", player_id, race_time, lap_number)
		emit_signal("race_completed", player_id, race_time)
		print("RACE WON! Player %d finished %d laps in %.2f seconds!" % [player_id, lap_number, race_time])
		if player_id == multiplayer.get_unique_id():
			SoundManager.play_sound(SoundManager.SoundCatalog.FINISH)
		return true
	else:
		start_new_lap(player_id)
		if player_id == multiplayer.get_unique_id():
			SoundManager.play_sound(SoundManager.SoundCatalog.LAP)
		return false

func start_new_lap(player_id: int) -> void:
	var spawn_position = Vector3.ZERO
	var spawn_rotation = 0.0
	if spawn_points.size() > 0:
		var spawn_id = spawn_points.keys()[0]
		spawn_position = spawn_points[spawn_id]["position"]
		spawn_rotation = spawn_points[spawn_id]["rotation_y"]
	player_checkpoints[player_id] = []
	player_current_lap[player_id] += 1
	player_respawns[player_id] = spawn_position
	player_respawn_rotations[player_id] = spawn_rotation
	if debug_mode:
		print("Starting lap %d for player %d - Respawn point set to starting position %s" % 
			  [player_current_lap[player_id], player_id, spawn_position])

func set_required_laps(laps: int) -> void:
	if laps > 0:
		required_laps = laps
		if debug_mode:
			print("Race configured for %d laps" % required_laps)

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
	SoundManager.play_sound(SoundManager.SoundCatalog.RESPAWN)


func get_respawn_position(player_id: int) -> Vector3:
	if player_respawns.has(player_id):
		return player_respawns[player_id]
	return Vector3.ZERO

func get_respawn_rotation(player_id: int) -> float:
	if player_respawn_rotations.has(player_id):
		return player_respawn_rotations[player_id]
	return 0.0

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
	player_current_lap[player_id] = 1
	player_completed_laps[player_id] = 0
	if debug_mode:
		print("Reset race progress for player %d" % player_id)

func reset_race() -> void:
	player_checkpoints.clear()
	player_race_times.clear()
	player_respawning.clear()
	if debug_mode:
		print("Race system reset")

func reset_race_manager() -> void:
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
	player_current_lap.clear()
	player_completed_laps.clear()
	player_final_times.clear()
	
	if debug_mode:
		print("Race system completely reset")
		
func record_final_time(player_id: int, race_time: float) -> void:
	player_final_times[player_id] = race_time
	if multiplayer.is_server():
		sync_race_times.rpc(player_final_times)
		emit_signal("all_race_times_received", player_final_times)
	elif player_id == multiplayer.get_unique_id():
		send_race_time_to_server.rpc_id(1, player_id, race_time)
		
@rpc("reliable", "any_peer")
func send_race_time_to_server(player_id: int, race_time: float) -> void:
	if not multiplayer.is_server():
		return
	player_final_times[player_id] = race_time
	sync_race_times.rpc(player_final_times)
	
	emit_signal("all_race_times_received", player_final_times)
@rpc("reliable")
func sync_race_times(times: Dictionary) -> void:
	player_final_times = times
	emit_signal("all_race_times_received", player_final_times)

func clear_race_times() -> void:
	player_final_times.clear()
	
func get_sorted_race_times() -> Array:
	var times_array = []
	for player_id in player_final_times:
		times_array.append({
			"player_id": player_id,
			"time": player_final_times[player_id],
			"player_name": NetworkManager.lobby_members.get(player_id, "Player " + str(player_id))
		})
	times_array.sort_custom(func(a, b): return a.time < b.time)
	return times_array
