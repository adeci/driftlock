extends MarginContainer


signal avatar_loaded


@export var player_container: MarginContainer
@export var player_col_1: VBoxContainer
@export var player_col_2: VBoxContainer

var peer_id: int
var cached_avatar_texture: ImageTexture
var col := false:
	get:
		col = not col
		return col
var current_col: VBoxContainer:
	get:
		if col:
			return player_col_1
		else:
			return player_col_2
var player_banners: Array

@onready var row_count: int = 0


func _ready() -> void:
	# Multiplayer Signals
	NetworkManager.player_connected.connect(_on_player_joined)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	NetworkManager.server_disconnected.connect(_on_exit_pressed)
	
	# Steam Signals
	if NetworkManager.steam_status:
		Steam.avatar_loaded.connect(_on_loaded_avatar)
	
	# Player Banners
	for i in range(NetworkManager.player_limit):
		var player = player_container.duplicate()
		player.visible = false
		player_banners.append(player)
		current_col.add_child(player)


func _on_visibility() -> void:
	if get_tree().paused:
		get_tree().paused = false
	if NetworkManager.steam_status:
		Steam.getPlayerAvatar()
		await avatar_loaded
	else:
		NetworkManager.player_information[multiplayer.get_unique_id()] = TextureRect.new()
	redraw_lobby()


func redraw_lobby() -> void:
	for player_banner in player_banners:
		player_banner.visible = false
	var index: int = 0
	for key in NetworkManager.player_information.keys():
		var player_name = NetworkManager.lobby_members[key]
		var player_icon = NetworkManager.player_information[key]
		var player_banner = player_banners[index]
		player_banner.get_node("./PlayerInformation/PlayerTextContainer/PlayerName").text = player_name
		player_banner.get_node("./PlayerInformation/PlayerIcon/ProfileImage").set_texture(player_icon)
		player_banner.name = str(key)
		player_banner.visible = true
		index += 1


# Multiplayer Signal Functions
func _on_player_joined(new_peer_id: int, _player_name: String) -> void:
	if NetworkManager.steam_status:
		Steam.getPlayerAvatar(2, NetworkManager.peer.get_steam64_from_peer_id(new_peer_id))
		await avatar_loaded
	else:
		NetworkManager.player_information[new_peer_id] = TextureRect.new()
	redraw_lobby()


func _on_player_disconnected(old_peer_id: int) -> void:
	NetworkManager.player_information.erase(old_peer_id)
	redraw_lobby()


# Steam Signal Functions
func _on_loaded_avatar(user_id: int, avatar_size: int, avatar_buffer: PackedByteArray) -> void:
	# Create Image
	var avatar_image := Image.create_from_data(avatar_size, avatar_size, false, Image.FORMAT_RGBA8, avatar_buffer)
	
	# Resize Image
	if avatar_size > 64:
		avatar_image.resize(64, 64, Image.INTERPOLATE_LANCZOS)
	
	# Create texture
	var new_peer_id: int = NetworkManager.peer.get_peer_id_from_steam64(user_id)
	NetworkManager.player_information[new_peer_id] = ImageTexture.create_from_image(avatar_image)
	avatar_loaded.emit()


func _on_exit_pressed() -> void:
	NetworkManager.player_information.clear()
	redraw_lobby()
