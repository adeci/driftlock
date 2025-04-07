extends MarginContainer

@export var lobby_name_input: TextEdit
@export var lobby_mode_input: TextEdit
@export var lobby_type_id: OptionButton

var steam_lobby_types := [
	Steam.LOBBY_TYPE_PUBLIC,
	Steam.LOBBY_TYPE_PRIVATE,
	Steam.LOBBY_TYPE_FRIENDS_ONLY,
]


func set_lobby_parameters(lobby_name: String, lobby_mode: String, type: Steam.LobbyType):
	NetworkManager.lobby_name = lobby_name
	NetworkManager.lobby_mode = lobby_mode
	NetworkManager.lobby_type = type

func set_enet_parameters(ip_address: String, port: int):
	NetworkManager.address = ip_address
	NetworkManager.PORT = port


func _on_create_lobby_pressed() -> void:
	var lobby_name := lobby_name_input.text
	var lobby_mode := lobby_mode_input.text
	if lobby_name.is_empty():
		lobby_name = "Driftlock Lobby"
	if lobby_mode.is_empty():
		lobby_mode = "Arcade"
	set_lobby_parameters(lobby_name, lobby_mode, steam_lobby_types[lobby_type_id.get_selected_id()])
	NetworkManager.create_server()


func _on_create_lobby_pressed_enet() -> void:
	var ip_address := lobby_name_input.text
	var port := lobby_mode_input.text
	if ip_address.is_empty():
		ip_address = "localhost"
	if port.is_empty():
		port = "9999"
	set_enet_parameters(ip_address, int(port))
	NetworkManager.create_server()
	
