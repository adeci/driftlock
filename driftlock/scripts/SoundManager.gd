extends Node

# Sound types
enum SoundType {EFFECT, MUSIC}

# Sound categories
enum SoundCategory {
 	BUTTON1, BUTTON2, BUTTON3,
	PLAYER_MOVING, DRIFT, COLLISION1, COLLISION2,
	WATER_SUBMERGE, WATER_EMERGE, WATER_AMBIENCE, DOOR_OPEN,
	GO, RESPAWN, LAP, FINISH, TELE1, TELE2, TELE3,
	ITEM_PICKUP, JUMP_BOOST, SPEED_BOOST,SPEED_ENHANCE,
	MENU_MUSIC, BEACH_MUSIC, DUNGEON_MUSIC
}

# Stores all sound files
var sound_library: Dictionary = {}

# Custom loop points for music (in seconds)
# 0.0 means use default
var music_loop_points: Dictionary = {
	SoundCategory.MENU_MUSIC: {"start": 11.0, "end": 0.0},
	SoundCategory.BEACH_MUSIC: {"start": 0.0, "end": 0.0},
	SoundCategory.DUNGEON_MUSIC: {"start": 0.0, "end": 0.0},
}

# Mapping from SoundCategory enum to filenames
var sound_mappings: Dictionary = {}

# Audio player pools
var audio_pool_2d: Array[AudioStreamPlayer] = []
var audio_pool_3d: Array[AudioStreamPlayer3D] = []
var music_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer
var continuous_ambient_players: Dictionary = {}

# Config
var pool_size: int = 10
var spatial_sound_radius: float = 30.0
var sound_falloff: float = 2.0 
var sound_enabled: bool = true
var music_enabled: bool = true
var music_volume: float = 0.7
var sfx_volume: float = 1.0
var ambient_volume: float = 0.8
var current_music: SoundCategory = SoundCategory.MENU_MUSIC
var music_crossfade_time: float = 2.0

# Networking
var networked_sound_queue: Array = []
var process_network_interval: float = 0.1
var process_timer: float = 0.0

# Track custom loop points
var music_custom_loop_timer: Timer
var current_loop_points: Dictionary = {"start": 0.0, "end": 0.0}

func _ready() -> void:
	# Create audio players pool
	create_audio_pool()
	
	# Create music player
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	music_player.volume_db = linear_to_db(music_volume)
	add_child(music_player)
	
	# Create ambient player
	ambient_player = AudioStreamPlayer.new()
	ambient_player.bus = "Ambient"
	ambient_player.volume_db = linear_to_db(ambient_volume)
	add_child(ambient_player)
	
	# Setup continuous ambient sounds
	setup_continuous_ambient_players()
	
	# Setup music loop timer
	music_custom_loop_timer = Timer.new()
	music_custom_loop_timer.one_shot = true
	music_custom_loop_timer.autostart = false
	music_custom_loop_timer.timeout.connect(_on_music_loop_point_reached)
	add_child(music_custom_loop_timer)
	
	# Connect to music player's finished signal for normal looping
	music_player.finished.connect(_on_music_finished)
	
	# Load sound mappings
	load_sound_mappings()
	
	# Connect network signals
	NetworkManager.player_connected.connect(_on_player_connected)
	
	# Preload sounds
	preload_sounds()

func _process(delta: float) -> void:
	# Process networked sound queue
	process_timer += delta
	if process_timer >= process_network_interval:
		process_timer = 0
		process_networked_sounds()
	
	# Check custom music loop points
	if music_player.playing and current_loop_points.end > 0:
		var current_pos = music_player.get_playback_position()
		if current_pos >= current_loop_points.end:
			music_player.seek(current_loop_points.start)

# Setup functions
func create_audio_pool() -> void:
	# Create 2D audio pool
	for i in range(pool_size):
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		player.finished.connect(_on_audio_finished.bind(player, false))
		player.max_polyphony = 1
		audio_pool_2d.append(player)
		add_child(player)
	
	# Create 3D audio pool
	for i in range(pool_size):
		var player = AudioStreamPlayer3D.new()
		player.bus = "SFX"
		player.max_distance = spatial_sound_radius
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
		player.unit_size = sound_falloff
		player.finished.connect(_on_audio_finished.bind(player, true))
		audio_pool_3d.append(player)
		add_child(player)

func setup_continuous_ambient_players() -> void:
	var ambient_categories = [
		SoundCategory.WATER_AMBIENCE
		]
	
	for category in ambient_categories:
		var player = AudioStreamPlayer.new()
		player.bus = "Ambient"
		player.volume_db = -80.0
		add_child(player)
		continuous_ambient_players[category] = {
			"player": player,
			"active": false,
			"target_volume": 0.0,
			"current_tween": null
		}

func load_sound_mappings() -> void:
	sound_mappings[SoundCategory.BUTTON1] = "res://assets/sounds/gameplay/button1.mp3"
	sound_mappings[SoundCategory.BUTTON2] = "res://assets/sounds/gameplay/button2.mp3"
	sound_mappings[SoundCategory.BUTTON3] = "res://assets/sounds/gameplay/button3.mp3"
	
	sound_mappings[SoundCategory.PLAYER_MOVING] = "res://assets/sounds/gameplay/player_moving.mp3"
	sound_mappings[SoundCategory.DRIFT] = ""
	sound_mappings[SoundCategory.COLLISION1] = "res://assets/sounds/gameplay/collision1.mp3"
	sound_mappings[SoundCategory.COLLISION2] = "res://assets/sounds/gameplay/collision2.mp3"
	
	sound_mappings[SoundCategory.WATER_SUBMERGE] = "res://assets/sounds/gameplay/water_submerge.mp3"
	sound_mappings[SoundCategory.WATER_EMERGE] = "res://assets/sounds/gameplay/water_emerge.mp3"
	sound_mappings[SoundCategory.WATER_AMBIENCE] = "res://assets/sounds/gameplay/water_ambiance.mp3"
	sound_mappings[SoundCategory.DOOR_OPEN] = "res://assets/sounds/gameplay/door_open.mp3"
	
	sound_mappings[SoundCategory.GO] = "res://assets/sounds/gameplay/go.mp3"
	sound_mappings[SoundCategory.RESPAWN] = "res://assets/sounds/gameplay/respawn.mp3"
	sound_mappings[SoundCategory.LAP] = "res://assets/sounds/gameplay/lap.mp3"
	sound_mappings[SoundCategory.FINISH] = ""
	sound_mappings[SoundCategory.TELE1] = "res://assets/sounds/gameplay/tele1.mp3"
	sound_mappings[SoundCategory.TELE2] = "res://assets/sounds/gameplay/tele2.mp3"
	sound_mappings[SoundCategory.TELE3] = "res://assets/sounds/gameplay/tele3.mp3"
	
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
		if ResourceLoader.exists(path):
			var stream = load(path)
			if stream:
				sound_library[category] = stream
				if category in [SoundCategory.WATER_AMBIENCE]:
					if stream is AudioStreamOggVorbis:
						stream.loop = true
		else:
			print("WARNING: Sound file not found: " + path)

func play_sound(category: SoundCategory, position: Vector3 = Vector3.ZERO, networked: bool = false) -> void:
	if not sound_enabled:
		return
	
	if networked and multiplayer.is_server():
		networked_sound_queue.append({
			"category": category,
			"position": position
		})
	if not sound_library.has(category):
		return
	var stream = sound_library[category]
	var is_3d = position != Vector3.ZERO
	if is_3d:
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

func play_music(category: SoundCategory, crossfade: bool = true) -> void:
	if not music_enabled or not sound_library.has(category):
		return
		
	if current_music == category and music_player.playing:
		return
		
	current_music = category
	var stream = sound_library[category]
	

	if music_loop_points.has(category):
		current_loop_points = music_loop_points[category]
	else:
		current_loop_points = {"start": 0.0, "end": 0.0}
	
	if crossfade and music_player.playing:

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

# Continuous ambient sound functions
func start_continuous_ambient(category: SoundCategory, fade_time: float = 1.0) -> void:
	if not continuous_ambient_players.has(category) or not sound_library.has(category):
		return
	
	var ambient_info = continuous_ambient_players[category]
	var player = ambient_info.player
	
	# If already active at target volume, do nothing
	if ambient_info.active and player.volume_db >= linear_to_db(ambient_volume):
		return
	
	# If not playing, start it
	if not player.playing:
		player.stream = sound_library[category]
		player.play()
	
	# Cancel any existing tween
	if ambient_info.current_tween and ambient_info.current_tween.is_valid():
		ambient_info.current_tween.kill()
	
	# Fade in
	ambient_info.active = true
	var tween = create_tween()
	tween.tween_property(player, "volume_db", linear_to_db(ambient_volume), fade_time)
	ambient_info.current_tween = tween

func stop_continuous_ambient(category: SoundCategory, fade_time: float = 1.0) -> void:
	if not continuous_ambient_players.has(category):
		return
	
	var ambient_info = continuous_ambient_players[category]
	var player = ambient_info.player
	
	# If already inactive, do nothing
	if not ambient_info.active:
		return
		
	# Cancel any existing tween
	if ambient_info.current_tween and ambient_info.current_tween.is_valid():
		ambient_info.current_tween.kill()
	
	# Fade out
	ambient_info.active = false
	var tween = create_tween()
	tween.tween_property(player, "volume_db", -80.0, fade_time)
	tween.tween_callback(func(): player.stop())
	ambient_info.current_tween = tween

# Player state-based sound functions
func update_player_water_state(in_water: bool, _player_position: Vector3) -> void:
	if in_water:
		# Start underwater ambient sound
		start_continuous_ambient(SoundCategory.WATER_AMBIENCE)
	else:
		# Stop underwater ambient sound
		stop_continuous_ambient(SoundCategory.WATER_AMBIENCE)

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

func _on_music_loop_point_reached() -> void:
	if music_player.playing and current_loop_points.start > 0:
		music_player.seek(current_loop_points.start)

# Sound settings
func set_music_volume(volume: float) -> void:
	music_volume = clamp(volume, 0.0, 1.0)
	music_player.volume_db = linear_to_db(music_volume)

func set_sfx_volume(volume: float) -> void:
	sfx_volume = clamp(volume, 0.0, 1.0)
	for player in audio_pool_2d:
		player.volume_db = linear_to_db(sfx_volume)
	for player in audio_pool_3d:
		player.unit_db_gain = linear_to_db(sfx_volume)

func set_ambient_volume(volume: float) -> void:
	ambient_volume = clamp(volume, 0.0, 1.0)
	ambient_player.volume_db = linear_to_db(ambient_volume)
	
	# Update continuous ambient players
	for category in continuous_ambient_players:
		var ambient_info = continuous_ambient_players[category]
		if ambient_info.active:
			ambient_info.player.volume_db = linear_to_db(ambient_volume)

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
	if not multiplayer.is_server() or networked_sound_queue.is_empty():
		return
		
	for sound_info in networked_sound_queue:
		play_networked_sound.rpc(sound_info.category, sound_info.position)
	
	networked_sound_queue.clear()

func _on_player_connected(_peer_id: int, _player_name: String) -> void:
	# When a new player connects, sync them with the current music
	if multiplayer.is_server() and current_music != -1:
		sync_music.rpc_id(_peer_id, current_music)

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
	# Play map-specific music
	match map_name:
		"beachzone":
			play_music(SoundCategory.BEACH_MUSIC)
		"dungeon":
			play_music(SoundCategory.DUNGEON_MUSIC)
