extends Node

# Sound types
enum SoundType {EFFECT, MUSIC}

# Sound categories
enum SoundCategory {
	# UI Sounds
	BUTTON1, BUTTON2, BUTTON3,
	
	# Player Sounds
	PLAYER_MOVING, DRIFT, COLLISION1, COLLISION2,
	
	# Environment Sounds
	WATER_SUBMERGE, WATER_EMERGE, WATER_AMBIENCE, DOOR_OPEN,
	
	# Race Sounds
	GO, RESPAWN, LAP, FINISH, TELE1, TELE2, TELE3,
	
	# Item Sounds
	ITEM_PICKUP, JUMP_BOOST, SPEED_BOOST, SPEED_ENHANCE,
	
	# Music
	MENU_MUSIC, BEACH_MUSIC, DUNGEON_MUSIC
}

# Audio player pools
var audio_pool_2d: Array[AudioStreamPlayer] = []
var audio_pool_3d: Array[AudioStreamPlayer3D] = []
var music_player: AudioStreamPlayer
var looping_players: Dictionary = {}

# Sound library - stores all loaded sound resources
var sound_library: Dictionary = {}

# Maps categories to file paths
var sound_mappings: Dictionary = {}

# Custom loop points for music (in seconds)
var music_loop_points: Dictionary = {
	SoundCategory.MENU_MUSIC: {"start": 11.0, "end": 0.0},
	SoundCategory.BEACH_MUSIC: {"start": 0.0, "end": 0.0},
	SoundCategory.DUNGEON_MUSIC: {"start": 0.0, "end": 0.0},
}

# Config
var pool_size: int = 10
var spatial_sound_radius: float = 30.0
var sound_falloff: float = 2.0 
var sound_enabled: bool = true
var music_enabled: bool = true
var music_volume: float = 0.7
var sfx_volume: float = 1.0
var music_crossfade_time: float = 2.0
var current_music: SoundCategory = SoundCategory.MENU_MUSIC

# Networking
var networked_sound_queue: Array = []
var process_network_interval: float = 0.1
var process_timer: float = 0.0

# Tracking variables
var current_loop_points: Dictionary = {"start": 0.0, "end": 0.0}
var first_play_tracker: Dictionary = {}
var players_in_water: Dictionary = {}

# Movement sound tracking
var movement_sound_players: Dictionary = {}
var movement_sound_start_times: Dictionary = {}
const MOVEMENT_SOUND_DURATION: float = 11.0
const MOVEMENT_SOUND_LOOP_START: float = 8.0  # 11 - 3 = 8 (last 3 seconds)

func _ready() -> void:
	# Create audio pools
	create_audio_pools()
	
	# Create music player
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	music_player.volume_db = linear_to_db(music_volume)
	add_child(music_player)
	
	# Connect to music player's finished signal for looping
	music_player.finished.connect(_on_music_finished)
	
	# Load sound mappings
	setup_sound_mappings()
	
	# Connect network signals
	NetworkManager.player_connected.connect(_on_player_connected)
	
	# Preload sounds
	preload_sounds()

func _process(delta: float) -> void:
	# Process networked sound queue on server
	if multiplayer.is_server():
		process_timer += delta
		if process_timer >= process_network_interval and networked_sound_queue.size() > 0:
			process_timer = 0.0
			process_networked_sounds()
	
	# Check custom music loop points
	if music_player.playing and current_loop_points.end > 0.0:
		var current_pos = music_player.get_playback_position()
		if current_pos >= current_loop_points.end:
			music_player.seek(current_loop_points.start)

# Core initialization functions
func create_audio_pools() -> void:
	# Create 2D audio pool
	for i in range(pool_size):
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		player.volume_db = linear_to_db(sfx_volume)
		player.finished.connect(_on_audio_finished.bind(player, false))
		audio_pool_2d.append(player)
		add_child(player)
	
	# Create 3D audio pool
	for i in range(pool_size):
		var player = AudioStreamPlayer3D.new()
		player.bus = "SFX"
		player.max_distance = spatial_sound_radius
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
		player.unit_size = sound_falloff
		player.unit_db = linear_to_db(sfx_volume)
		player.finished.connect(_on_audio_finished.bind(player, true))
		audio_pool_3d.append(player)
		add_child(player)

func setup_sound_mappings() -> void:
	# UI Sounds
	sound_mappings[SoundCategory.BUTTON1] = "res://assets/sounds/gameplay/button1.mp3"
	sound_mappings[SoundCategory.BUTTON2] = "res://assets/sounds/gameplay/button2.mp3"
	sound_mappings[SoundCategory.BUTTON3] = "res://assets/sounds/gameplay/button3.mp3"
	
	# Player Sounds
	sound_mappings[SoundCategory.PLAYER_MOVING] = "res://assets/sounds/gameplay/player_moving.mp3"
	sound_mappings[SoundCategory.DRIFT] = ""
	sound_mappings[SoundCategory.COLLISION1] = "res://assets/sounds/gameplay/collision1.mp3"
	sound_mappings[SoundCategory.COLLISION2] = "res://assets/sounds/gameplay/collision2.mp3"
	
	# Environment Sounds
	sound_mappings[SoundCategory.WATER_SUBMERGE] = "res://assets/sounds/gameplay/water_submerge.mp3"
	sound_mappings[SoundCategory.WATER_EMERGE] = "res://assets/sounds/gameplay/water_emerge.mp3"
	sound_mappings[SoundCategory.WATER_AMBIENCE] = "res://assets/sounds/gameplay/water_ambiance.mp3"
	sound_mappings[SoundCategory.DOOR_OPEN] = "res://assets/sounds/gameplay/door_open.mp3"
	
	# Race Sounds
	sound_mappings[SoundCategory.GO] = "res://assets/sounds/gameplay/go.mp3"
	sound_mappings[SoundCategory.RESPAWN] = "res://assets/sounds/gameplay/respawn.mp3"
	sound_mappings[SoundCategory.LAP] = "res://assets/sounds/gameplay/lap.mp3"
	sound_mappings[SoundCategory.FINISH] = ""
	sound_mappings[SoundCategory.TELE1] = "res://assets/sounds/gameplay/tele1.mp3"
	sound_mappings[SoundCategory.TELE2] = "res://assets/sounds/gameplay/tele2.mp3"
	sound_mappings[SoundCategory.TELE3] = "res://assets/sounds/gameplay/tele3.mp3"
	
	# Item Sounds
	sound_mappings[SoundCategory.ITEM_PICKUP] = "res://assets/sounds/gameplay/item_pickup.mp3"
	sound_mappings[SoundCategory.SPEED_BOOST] = "res://assets/sounds/gameplay/speed_boost.mp3"
	sound_mappings[SoundCategory.JUMP_BOOST] = "res://assets/sounds/gameplay/jump.mp3"
	sound_mappings[SoundCategory.SPEED_ENHANCE] = ""
	
	# Music
	sound_mappings[SoundCategory.MENU_MUSIC] = "res://assets/sounds/music/menu.mp3"
	sound_mappings[SoundCategory.BEACH_MUSIC] = "res://assets/sounds/music/beach.mp3"
	sound_mappings[SoundCategory.DUNGEON_MUSIC] = "res://assets/sounds/music/dungeon.mp3"

func preload_sounds() -> void:
	for category in sound_mappings:
		var path = sound_mappings[category]
		if path.is_empty():
			continue
			
		if ResourceLoader.exists(path):
			var stream = load(path)
			if stream is AudioStream:
				sound_library[category] = stream
		else:
			print("WARNING: Sound file not found: " + path)

# Sound playback functions
func play_sound(category: SoundCategory, position: Vector3 = Vector3.ZERO, networked: bool = false) -> void:
	if not sound_enabled:
		return
	
	# If networked sound and we're the server, queue it for broadcasting
	if networked and multiplayer.is_server():
		networked_sound_queue.append({
			"category": category,
			"position": position
		})
	
	# Skip if sound doesn't exist
	if not sound_library.has(category):
		return
		
	var stream = sound_library[category]
	
	# Play as 3D sound if position is specified
	if position != Vector3.ZERO:
		var player = get_free_player_3d()
		if player:
			player.stream = stream
			player.position = position
			player.play()
	else:
		var player = get_free_player_2d()
		if player:
			player.stream = stream
			player.play()

func play_sound_looping(category: SoundCategory, position: Vector3 = Vector3.ZERO) -> void:
	if not sound_enabled or not sound_library.has(category):
		return
	
	# If already playing this looped sound, do nothing
	if looping_players.has(category) and looping_players[category].playing:
		return
	
	var stream = sound_library[category]
	
	# Set stream to loop
	if stream is AudioStreamMP3:
		stream.loop = true
	
	var player
	if position != Vector3.ZERO:
		player = AudioStreamPlayer3D.new()
		player.bus = "SFX"
		player.max_distance = spatial_sound_radius
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
		player.unit_size = sound_falloff
		player.unit_db = linear_to_db(sfx_volume)
		player.position = position
	else:
		player = AudioStreamPlayer.new()
		player.bus = "SFX"
		player.volume_db = linear_to_db(sfx_volume)
	
	add_child(player)
	player.stream = stream
	player.play()
	
	looping_players[category] = player

func stop_sound_looping(category: SoundCategory) -> void:
	if not looping_players.has(category):
		return
		
	var player = looping_players[category]
	if player.playing:
		player.stop()
		player.queue_free()
		looping_players.erase(category)

func play_music(category: SoundCategory, crossfade: bool = true) -> void:
	if not music_enabled or not sound_library.has(category):
		return
		
	if current_music == category and music_player.playing:
		return
	
	# Track if this is a different track than what's currently playing
	var is_new_track = current_music != category
	current_music = category
	
	# Reset first play tracker for new tracks
	if is_new_track:
		first_play_tracker[category] = true
		
	var stream = sound_library[category]
	
	# Set up custom loop points
	if music_loop_points.has(category):
		current_loop_points = music_loop_points[category]
	else:
		current_loop_points = {"start": 0.0, "end": 0.0}
	
	if crossfade and music_player.playing:
		# Create temporary player for crossfade
		var temp_player = AudioStreamPlayer.new()
		temp_player.bus = "Music"
		temp_player.stream = stream
		temp_player.volume_db = -80.0
		add_child(temp_player)
		temp_player.play()
		
		# Fade out current music
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -80.0, music_crossfade_time)
		
		# Fade in new music
		var tween2 = create_tween()
		tween2.tween_property(temp_player, "volume_db", linear_to_db(music_volume), music_crossfade_time)
		
		# After crossfade, swap players
		await tween.finished
		music_player.stop()
		music_player.stream = stream
		music_player.volume_db = linear_to_db(music_volume)
		music_player.play(temp_player.get_playback_position())
		temp_player.queue_free()
	else:
		# Just play the new music
		if music_player.playing:
			music_player.stop()
		music_player.stream = stream
		music_player.volume_db = linear_to_db(music_volume)
		music_player.play()
	
	# After playing the music, connect to the finished signal with custom handler
	music_player.finished.disconnect(_on_music_finished) if music_player.is_connected("finished", _on_music_finished) else null
	music_player.finished.connect(_on_music_finished_custom.bind(category))

func stop_music(fade_out: bool = true, fade_time: float = 1.0) -> void:
	if not music_player.playing:
		return
		
	if fade_out:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -80.0, fade_time)
		await tween.finished
		music_player.stop()
	else:
		music_player.stop()

# Water state functions
func player_entered_water(player_id: int, position: Vector3) -> void:
	# Play splash sound (networked so all players hear it)
	play_sound(SoundCategory.WATER_SUBMERGE, position, true)
	
	# Track that this player is in water
	players_in_water[player_id] = true
	
	# Start underwater ambiance for this player (only local - each player hears their own)
	if player_id == multiplayer.get_unique_id():
		play_sound_looping(SoundCategory.WATER_AMBIENCE)

func player_exited_water(player_id: int, position: Vector3) -> void:
	# Play emerge sound (networked)
	play_sound(SoundCategory.WATER_EMERGE, position, true)
	
	# Remove tracking for this player
	players_in_water.erase(player_id)
	
	# Stop underwater ambiance for local player
	if player_id == multiplayer.get_unique_id():
		stop_sound_looping(SoundCategory.WATER_AMBIENCE)

# Player movement sound
func update_player_movement_sound(player_id: int, is_moving: bool, speed_factor: float = 1.0) -> void:
	# Only process for local player
	if player_id != multiplayer.get_unique_id():
		return
	
	if is_moving and speed_factor > 0.1:  # Only play sound if moving at a noticeable speed
		var current_time = Time.get_ticks_msec() / 1000.0
		
		# If not already tracking this player's movement
		if not movement_sound_players.has(player_id):
			# Create a dedicated player for movement sound
			var player = AudioStreamPlayer.new()
			player.bus = "SFX"
			player.volume_db = linear_to_db(sfx_volume * speed_factor)
			add_child(player)
			
			# Set up the movement sound
			player.stream = sound_library[SoundCategory.PLAYER_MOVING]
			player.play(0)
			
			# Track this player
			movement_sound_players[player_id] = player
			movement_sound_start_times[player_id] = current_time
		else:
			# Player already moving, update sound if needed
			var player = movement_sound_players[player_id]
			var movement_duration = current_time - movement_sound_start_times[player_id]
			
			# If we've passed the full duration, loop back to the loop start point
			if movement_duration > MOVEMENT_SOUND_DURATION:
				if player.get_playback_position() >= MOVEMENT_SOUND_DURATION:
					player.seek(MOVEMENT_SOUND_LOOP_START)
			
			# Adjust volume based on speed factor
			player.volume_db = linear_to_db(sfx_volume * speed_factor)
	else:
		# Player stopped moving, clean up
		if movement_sound_players.has(player_id):
			var player = movement_sound_players[player_id]
			
			# Fade out the sound
			var tween = create_tween()
			tween.tween_property(player, "volume_db", -80.0, 0.3)
			tween.tween_callback(func():
				player.stop()
				player.queue_free()
				movement_sound_players.erase(player_id)
				movement_sound_start_times.erase(player_id)
			)

# Helper functions
func get_free_player_2d() -> AudioStreamPlayer:
	for player in audio_pool_2d:
		if not player.playing:
			return player
	
	# If all are busy, use the oldest one
	return audio_pool_2d[0]

func get_free_player_3d() -> AudioStreamPlayer3D:
	for player in audio_pool_3d:
		if not player.playing:
			return player
	
	# If all are busy, use the oldest one
	return audio_pool_3d[0]

func _on_audio_finished(player, is_3d: bool) -> void:
	# Move player to the end of the array to implement a simple age system
	if is_3d:
		audio_pool_3d.erase(player)
		audio_pool_3d.append(player)
	else:
		audio_pool_2d.erase(player)
		audio_pool_2d.append(player)

func _on_music_finished() -> void:
	# If this track has custom loop points, handle looping manually
	if current_loop_points.start > 0:
		music_player.play(current_loop_points.start)
	else:
		# Otherwise just restart from the beginning
		music_player.play()

func _on_music_finished_custom(category: SoundCategory) -> void:
	# Special handling for menu music loop points
	if category == SoundCategory.MENU_MUSIC:
		if first_play_tracker.get(category, true):
			# First play finished, next time start at loop point
			first_play_tracker[category] = false
			music_player.play(0) # Restart from beginning for first loop
		else:
			# Subsequent plays, start at custom loop point
			music_player.play(11.0)
	else:
		# Handle normal looping for other music
		_on_music_finished()

# Sound settings
func set_music_volume(volume: float) -> void:
	music_volume = clamp(volume, 0.0, 1.0)
	music_player.volume_db = linear_to_db(music_volume)

func set_sfx_volume(volume: float) -> void:
	sfx_volume = clamp(volume, 0.0, 1.0)
	for player in audio_pool_2d:
		player.volume_db = linear_to_db(sfx_volume)
	for player in audio_pool_3d:
		player.unit_db = linear_to_db(sfx_volume)

func set_sound_enabled(enabled: bool) -> void:
	sound_enabled = enabled

func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	if not enabled and music_player.playing:
		stop_music()
	elif enabled and not music_player.playing and current_music != -1:
		play_music(current_music, false)

# Networking functions
func process_networked_sounds() -> void:
	if networked_sound_queue.is_empty():
		return
		
	for sound_info in networked_sound_queue:
		play_networked_sound.rpc(sound_info.category, sound_info.position)
	
	networked_sound_queue.clear()

func _on_player_connected(peer_id: int, _player_name: String) -> void:
	# When a new player connects, sync them with the current music
	if multiplayer.is_server() and current_music != -1:
		sync_music.rpc_id(peer_id, current_music)

# RPC functions
@rpc("reliable", "any_peer", "call_local")
func play_networked_sound(category: SoundCategory, position: Vector3) -> void:
	# Skip if this is the originating peer
	if multiplayer.get_remote_sender_id() == multiplayer.get_unique_id():
		return
		
	play_sound(category, position, false)

@rpc("reliable", "authority", "call_local")
func sync_music(category: SoundCategory) -> void:
	play_music(category, false)

# Level-specific functions
func play_map_music(map_name: String) -> void:
	match map_name:
		"beachzone":
			play_music(SoundCategory.BEACH_MUSIC)
		"dungeon":
			play_music(SoundCategory.DUNGEON_MUSIC)
		_:
			play_music(SoundCategory.MENU_MUSIC)
