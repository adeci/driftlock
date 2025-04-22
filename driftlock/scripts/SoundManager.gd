extends Node

# Sound types
enum SoundType {EFFECT, MUSIC}

# Sound categories
enum SoundCatalog {
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

var sound_volume_modifiers: Dictionary = {
	SoundCatalog.RESPAWN: -15.0,
	SoundCatalog.BUTTON1: -9.0,
	SoundCatalog.BUTTON2: -9.0,
	SoundCatalog.BUTTON3: -9.0,
	SoundCatalog.TELE1: -10.0,
	SoundCatalog.TELE2: -10.0,
	SoundCatalog.TELE3: -10.0,
	SoundCatalog.ITEM_PICKUP: -7.0,
	SoundCatalog.LAP: -15.0,
	SoundCatalog.WATER_SUBMERGE: -20.0,
	SoundCatalog.WATER_EMERGE: -20.0,
	SoundCatalog.WATER_AMBIENCE: -8.0,
	SoundCatalog.SPEED_BOOST: 10.0,
}

# Audio player pools
var audio_pool_2d: Array[AudioStreamPlayer] = []
var audio_pool_3d: Array[AudioStreamPlayer3D] = []

var spatial_sound_boost: float = 20.0

var music_player: AudioStreamPlayer
var looping_players: Dictionary = {}


# Sound library - stores all loaded sound resources
var sound_library: Dictionary = {}

# Maps categories to file paths
var sound_mappings: Dictionary = {}

# Custom loop points for music (in seconds)
var music_loop_points: Dictionary = {
	SoundCatalog.MENU_MUSIC: {"start": 11.4, "end": 0.0},
	SoundCatalog.BEACH_MUSIC: {"start": 0.0, "end": 0.0},
	SoundCatalog.DUNGEON_MUSIC: {"start": 0.0, "end": 0.0},
}

# Config
var pool_size: int = 10
var spatial_sound_radius: float = 50.0
var sound_falloff: float = 2.0 
var sound_enabled: bool = true
var music_enabled: bool = true
var music_volume: float = 0.7
var sfx_volume: float = 1.0
var music_crossfade_time: float = 2.0
var current_music: SoundCatalog = SoundCatalog.MENU_MUSIC

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
	var audio_bus_names = ["Master", "Music", "SFX"]
	for bus_name in audio_bus_names:
		if AudioServer.get_bus_index(bus_name) == -1:
			var bus_index = AudioServer.bus_count
			AudioServer.add_bus()
			AudioServer.set_bus_name(bus_index, bus_name)
			AudioServer.set_bus_send(bus_index, "Master")
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
func is_multiplayer_active() -> bool:
		return multiplayer != null and multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED
	
func _process(delta: float) -> void:
	# Process networked sound queue on server
	if is_multiplayer_active() and multiplayer.is_server():
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
		player.max_distance = 70.0
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
		player.unit_size = 20.0
		player.volume_db = linear_to_db(sfx_volume)
		player.finished.connect(_on_audio_finished.bind(player, true))
		audio_pool_3d.append(player)
		add_child(player)

func setup_sound_mappings() -> void:
	# UI Sounds
	sound_mappings[SoundCatalog.BUTTON1] = "res://assets/audio/gameplay/button1.mp3"
	sound_mappings[SoundCatalog.BUTTON2] = "res://assets/audio/gameplay/button2.mp3"
	sound_mappings[SoundCatalog.BUTTON3] = "res://assets/audio/gameplay/button3.mp3"
	
	# Player Sounds
	sound_mappings[SoundCatalog.PLAYER_MOVING] = "res://assets/audio/gameplay/player_moving.mp3"
	sound_mappings[SoundCatalog.DRIFT] = ""
	sound_mappings[SoundCatalog.COLLISION1] = "res://assets/audio/gameplay/collision1.mp3"
	sound_mappings[SoundCatalog.COLLISION2] = "res://assets/audio/gameplay/collision2.mp3"
	
	# Environment Sounds
	sound_mappings[SoundCatalog.WATER_SUBMERGE] = "res://assets/audio/gameplay/water_submerge.mp3"
	sound_mappings[SoundCatalog.WATER_EMERGE] = "res://assets/audio/gameplay/water_emerge.mp3"
	sound_mappings[SoundCatalog.WATER_AMBIENCE] = "res://assets/audio/gameplay/water_ambiance.mp3"
	sound_mappings[SoundCatalog.DOOR_OPEN] = "res://assets/audio/gameplay/door_open.mp3"
	
	# Race Sounds
	sound_mappings[SoundCatalog.GO] = "res://assets/audio/gameplay/go.mp3"
	sound_mappings[SoundCatalog.RESPAWN] = "res://assets/audio/gameplay/respawn.mp3"
	sound_mappings[SoundCatalog.LAP] = "res://assets/audio/gameplay/lap.mp3"
	sound_mappings[SoundCatalog.FINISH] = "res://assets/audio/gameplay/finish.mp3"
	sound_mappings[SoundCatalog.TELE1] = "res://assets/audio/gameplay/tele1.mp3"
	sound_mappings[SoundCatalog.TELE2] = "res://assets/audio/gameplay/tele2.mp3"
	sound_mappings[SoundCatalog.TELE3] = "res://assets/audio/gameplay/tele3.mp3"
	
	# Item Sounds
	sound_mappings[SoundCatalog.ITEM_PICKUP] = "res://assets/audio/gameplay/item_pickup.mp3"
	sound_mappings[SoundCatalog.SPEED_BOOST] = "res://assets/audio/gameplay/speed_boost.mp3"
	sound_mappings[SoundCatalog.JUMP_BOOST] = "res://assets/audio/gameplay/jump.mp3"
	sound_mappings[SoundCatalog.SPEED_ENHANCE] = ""
	
	# Music
	sound_mappings[SoundCatalog.MENU_MUSIC] = "res://assets/audio/music/menu.mp3"
	sound_mappings[SoundCatalog.BEACH_MUSIC] = "res://assets/audio/music/tropical.mp3"
	sound_mappings[SoundCatalog.DUNGEON_MUSIC] = "res://assets/audio/music/dungeon.mp3"

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
func play_sound(category: SoundCatalog, networked: bool = false, position: Vector3 = Vector3.ZERO) -> void:
	if not sound_enabled:
		return
	var volume_modifier = sound_volume_modifiers.get(category, 0.0)
	if networked and multiplayer.is_server():
		networked_sound_queue.append({
			"category": category,
			"position": position
		})
	if not sound_library.has(category):
		return
	var stream = sound_library[category]
	if position != Vector3.ZERO:
		var player = get_free_player_3d()
		if player:
			player.stream = stream
			player.position = position
			player.volume_db = linear_to_db(sfx_volume) + volume_modifier + spatial_sound_boost
			player.play()
	else:
		var player = get_free_player_2d()
		if player:
			player.stream = stream
			player.volume_db = linear_to_db(sfx_volume) + volume_modifier
			player.play()

func play_sound_looping(category: SoundCatalog, position: Vector3 = Vector3.ZERO) -> void:
	if not sound_enabled or not sound_library.has(category):
		return
	if looping_players.has(category) and looping_players[category].playing:
		return
	var stream = sound_library[category]
	if stream is AudioStreamMP3:
		stream.loop = true
	var player
	if position != Vector3.ZERO:
		player = AudioStreamPlayer3D.new()
		player.bus = "SFX"
		player.max_distance = spatial_sound_radius
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
		player.unit_size = sound_falloff
		player.volume_db = linear_to_db(sfx_volume)
		player.position = position
	else:
		player = AudioStreamPlayer.new()
		player.bus = "SFX"
		player.volume_db = linear_to_db(sfx_volume)
	
	add_child(player)
	player.stream = stream
	player.play()
	
	looping_players[category] = player

func stop_sound_looping(category: SoundCatalog) -> void:
	if not looping_players.has(category):
		return
		
	var player = looping_players[category]
	if player.playing:
		player.stop()
		player.queue_free()
		looping_players.erase(category)


func play_music(category: SoundCatalog, crossfade: bool = true) -> void:
	if not music_enabled or not sound_library.has(category):
		return
		
	if current_music == category and music_player.playing:
		return
	
	current_music = category
	var stream = sound_library[category]
	
	# Set up custom loop points
	if music_loop_points.has(category):
		current_loop_points = music_loop_points[category]
	else:
		current_loop_points = {"start": 0.0, "end": 0.0}
	
	if music_player.playing:
		music_player.stop()

	music_player.stream = stream
	music_player.volume_db = linear_to_db(music_volume)
	music_player.play()
	
	if music_player.is_connected("finished", Callable(self, "_on_music_finished")):
		music_player.finished.disconnect(Callable(self, "_on_music_finished"))
	
	for category_enum in SoundCatalog.values():
		var method = Callable(self, "_on_music_finished_custom").bind(category_enum)
		if music_player.is_connected("finished", method):
			music_player.finished.disconnect(method)
	
	music_player.finished.connect(_on_music_finished_custom.bind(category))
	

	var connections = music_player.get_signal_connection_list("finished")
	for connection in connections:
		music_player.finished.disconnect(connection.callable)
	music_player.finished.connect(_on_music_finished_custom.bind(category))

func stop_music(fade_out: bool = true, fade_time: float = 1.0) -> void:
	if not is_instance_valid(music_player) or not music_player.playing:
		return
	music_player.stop()

# Water
func player_entered_water(player_id: int, position: Vector3) -> void:
	play_sound(SoundCatalog.WATER_SUBMERGE, true, position)
	players_in_water[player_id] = true
	if player_id == multiplayer.get_unique_id():
		play_sound_looping(SoundCatalog.WATER_AMBIENCE)

func player_exited_water(player_id: int, position: Vector3) -> void:
	play_sound(SoundCatalog.WATER_EMERGE, true, position)
	players_in_water.erase(player_id)
	if player_id == multiplayer.get_unique_id():
		stop_sound_looping(SoundCatalog.WATER_AMBIENCE)

func update_player_movement_sound(player_id: int, is_moving: bool, speed_factor: float = 1.0) -> void:
	if player_id != multiplayer.get_unique_id():
		return
	
	if is_moving and speed_factor > 0.1:
		var current_time = Time.get_ticks_msec() / 1000.0
		
		if not movement_sound_players.has(player_id):
			var player = AudioStreamPlayer.new()
			player.bus = "SFX"
			player.volume_db = linear_to_db(sfx_volume * speed_factor)
			add_child(player)
			
			player.stream = sound_library[SoundCatalog.PLAYER_MOVING]
			player.play(0)
			movement_sound_players[player_id] = player
			movement_sound_start_times[player_id] = current_time
		else:
			var player = movement_sound_players[player_id]
			var movement_duration = current_time - movement_sound_start_times[player_id]

			if movement_duration > MOVEMENT_SOUND_DURATION:
				if player.get_playback_position() >= MOVEMENT_SOUND_DURATION:
					player.seek(MOVEMENT_SOUND_LOOP_START)

			player.volume_db = linear_to_db(sfx_volume * speed_factor)
	else:
		if movement_sound_players.has(player_id):
			var player = movement_sound_players[player_id]
			var stored_player_id = player_id
			var tween = create_tween()
			tween.tween_property(player, "volume_db", -80.0, 0.3)
			tween.tween_callback(func():
				if movement_sound_players.has(stored_player_id):
					var sound_player = movement_sound_players[stored_player_id]
					if is_instance_valid(sound_player):
						sound_player.stop()
						sound_player.queue_free()
					movement_sound_players.erase(stored_player_id)
					movement_sound_start_times.erase(stored_player_id)
			)

func get_free_player_2d() -> AudioStreamPlayer:
	for player in audio_pool_2d:
		if not player.playing:
			return player
	return audio_pool_2d[0]

func get_free_player_3d() -> AudioStreamPlayer3D:
	for player in audio_pool_3d:
		if not player.playing:
			return player
	return audio_pool_3d[0]

func _on_audio_finished(player, is_3d: bool) -> void:
	if is_3d:
		audio_pool_3d.erase(player)
		audio_pool_3d.append(player)
	else:
		audio_pool_2d.erase(player)
		audio_pool_2d.append(player)

func _on_music_finished() -> void:
	if not is_instance_valid(music_player):
		return
	if current_loop_points.start > 0:
		music_player.play(current_loop_points.start)
	else:
		music_player.play()

func _on_music_finished_custom(category: SoundCatalog) -> void:
	if category == null or not is_instance_valid(music_player):
		return
	if category == SoundCatalog.MENU_MUSIC:
		if first_play_tracker.get(category, true):
			first_play_tracker[category] = false
			if is_instance_valid(music_player):
				music_player.play(0)
		else:
			if is_instance_valid(music_player):
				music_player.play(11.0)
	else:
		if is_instance_valid(music_player):
			if current_loop_points.start > 0:
				music_player.play(current_loop_points.start)
			else:
				music_player.play()

func set_music_volume(volume: float) -> void:
	music_volume = clamp(volume, 0.0, 1.0)
	music_player.volume_db = linear_to_db(music_volume)

func set_sfx_volume(volume: float) -> void:
	sfx_volume = clamp(volume, 0.0, 1.0)
	for player in audio_pool_2d:
		player.volume_db = linear_to_db(sfx_volume)
	for player in audio_pool_3d:
		player.volume_db = linear_to_db(sfx_volume)

func set_sound_enabled(enabled: bool) -> void:
	sound_enabled = enabled

func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	if not enabled and music_player.playing:
		stop_music()
	elif enabled and not music_player.playing and current_music != -1:
		play_music(current_music, false)

func process_networked_sounds() -> void:
	if networked_sound_queue.is_empty():
		return
		
	for sound_info in networked_sound_queue:
		play_networked_sound.rpc(sound_info.category, sound_info.position)
	
	networked_sound_queue.clear()

func _on_player_connected(peer_id: int, _player_name: String) -> void:
	if multiplayer.is_server() and current_music != -1:
		sync_music.rpc_id(peer_id, current_music)

# RPC functions
@rpc("reliable", "any_peer", "call_local")
func play_networked_sound(category: SoundCatalog, position: Vector3) -> void:
	if multiplayer.get_remote_sender_id() == multiplayer.get_unique_id():
		return
	play_sound(category, false, position)

@rpc("reliable", "authority", "call_local")
func sync_music(category: SoundCatalog) -> void:
	play_music(category, false)

func play_map_music(map_name: String) -> void:
	match map_name:
		"beachzone":
			play_music(SoundCatalog.BEACH_MUSIC)
		"dungeon":
			play_music(SoundCatalog.DUNGEON_MUSIC)
		_:
			play_music(SoundCatalog.MENU_MUSIC)
