extends MarginContainer


@export var sample_lobby_button: Button
@export var lobby_list: VBoxContainer
@export var ip_address: TextEdit
@export var port: TextEdit

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if NetworkManager.steam_status:
		Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_CLOSE)
		Steam.lobby_match_list.connect(_on_lobby_match_list)


# Steam Signals
func _on_lobby_match_list(these_lobbies: Array) -> void:
	var children = lobby_list.get_children()
	for child in children:
		child.queue_free()
	for this_lobby in these_lobbies:
		
		# Pull lobby data from Steam, these are specific to our example
		var lobby_name: String = Steam.getLobbyData(this_lobby, "name")
		var lobby_mode: String = Steam.getLobbyData(this_lobby, "mode")
		
		# Get the current number of members
		var lobby_num_members: int = Steam.getNumLobbyMembers(this_lobby)
		
		# Create a button for the lobby
		var lobby_button: Button = sample_lobby_button.duplicate()
		lobby_button.set_text("%s [%s] - %s Player(s)" % [lobby_name, lobby_mode, lobby_num_members])
		lobby_button.set_name("lobby_%s" % this_lobby)
		lobby_button.pressed.connect(NetworkManager.create_client.bind(this_lobby))
		
		# Add the new lobby to the list
		lobby_list.add_child(lobby_button)


func _on_join_pressed() -> void:
	if NetworkManager.steam_status:
		Steam.requestLobbyList()


func _on_play_pressed() -> void:
	var ip = ip_address.text
	var new_port = port.text
	if ip.is_empty():
		ip = "localhost"
	if new_port.is_empty():
		new_port = "9999"
	
	NetworkManager.address = ip
	NetworkManager.PORT = int(new_port)
	
	NetworkManager.create_client()
