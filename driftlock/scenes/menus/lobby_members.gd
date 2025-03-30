extends MarginContainer


signal avatar_loaded

@export var player_container: MarginContainer
@export var player_col_1: VBoxContainer
@export var player_col_2: VBoxContainer

var peer_id: int
var player_banners: Dictionary
var cached_avatar_texture: ImageTexture
var col := true:
	get:
		col = not col
		return col
var current_col: VBoxContainer:
	get:
		if col:
			return player_col_1
		else:
			return player_col_2

@onready var row_count: int = 0


func _ready() -> void:
	# Multiplayer Signals
	NetworkManager.player_connected.connect(_on_player_joined)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	NetworkManager.server_disconnected.connect(_on_exit_pressed)
	
	# Steam Signals
	Steam.avatar_loaded.connect(_on_loaded_avatar)


func _on_visibility() -> void:
	var player = player_container.duplicate()
	player.get_node("./PlayerInformation/PlayerTextContainer/PlayerName").text = NetworkManager.player_info
	if NetworkManager.steam_status:
		var player_icon := player.get_node("./PlayerInformation/PlayerIcon/ProfileImage")
		Steam.getPlayerAvatar()
		await avatar_loaded
		player_icon.set_texture(cached_avatar_texture)
	await Steam.lobby_joined
	peer_id = multiplayer.get_unique_id()
	player.name = str(peer_id)
	player_banners[peer_id] = player
	player_col_1.add_child(player)


# Multiplayer Signal Functions
func _on_player_joined(peer_id: int, player_name: String) -> void:
	var new_player_container = player_container.duplicate()
	new_player_container.name = str(peer_id)
	new_player_container.get_node("./PlayerInformation/PlayerTextContainer/PlayerName").text = player_name
	var player_icon := new_player_container.get_node("./PlayerInformation/PlayerIcon/ProfileImage")
	Steam.getPlayerAvatar(2, NetworkManager.peer.get_steam64_from_peer_id(peer_id))
	await avatar_loaded
	player_icon.set_texture(cached_avatar_texture)
	current_col.add_child(new_player_container)
	player_banners[peer_id] = new_player_container


func _on_player_disconnected(peer_id: int) -> void:
	player_banners[peer_id].queue_free()
	player_banners.erase(peer_id)
	if player_banners.size() % 2:
		col = true
	else:
		col = false


# Steam Signal Functions
func _on_loaded_avatar(user_id: int, avatar_size: int, avatar_buffer: PackedByteArray) -> void:
	# Create Image
	var avatar_image := Image.create_from_data(avatar_size, avatar_size, false, Image.FORMAT_RGBA8, avatar_buffer)
	
	# Resize Image
	if avatar_size > 64:
		avatar_image.resize(64, 64, Image.INTERPOLATE_LANCZOS)
	
	# Create texture
	cached_avatar_texture = ImageTexture.create_from_image(avatar_image)
	avatar_loaded.emit()


func _on_exit_pressed() -> void:
	col = true
	for id in player_banners.keys():
		player_banners[id].queue_free()
		player_banners.erase(id)
