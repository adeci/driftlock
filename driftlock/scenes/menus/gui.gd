extends MarginContainer

var racing: bool
var placement: int
var current_lap: int = 1
var total_laps: int = 3

var timer: SceneTreeTimer
var race_results_visible: bool = false
var result_item_scene = preload("res://scenes/menus/race_results.tscn")
signal exit_to_lobby_requested
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	
	if not multiplayer.is_server() or NetworkManager.local:
		$MainMenu/ButtonsMenu/MenuLayers/Layer1/Buttons/Seperator/BottomButtons/ExitToLobby.visible = false

	$MainMenu.visible = false
	$RaceUI.visible = true
	
	var return_button = $RaceUI/RaceResults/VBoxContainer/ReturnToLobby
	if return_button:
		if NetworkManager.local:
			return_button.text = "Return to Menu"
		else:
			return_button.text = "Return to Lobby"
			return_button.visible = multiplayer.is_server()

	self.visible = true
	
	GameManager.item_collected.connect(_item_collected)
	GameManager.item_used.connect(_item_used)
	
	racing = false
	RaceManager.race_started.connect(_race_started)
	RaceManager.race_completed.connect(_race_completed)
	RaceManager.lap_completed.connect(_lap_completed)

	total_laps = RaceManager.required_laps
	update_lap_display()
	
	placement = 1
	
	timer = get_tree().create_timer(3, true)
	timer.timeout.connect(_start_race_for_player.bind(multiplayer.get_unique_id()))
	timer.timeout.connect(_hide_race_countdown)
	
	RaceManager.all_race_times_received.connect(_on_race_times_received)
	RaceManager.race_completed.connect(_on_race_completed)
	
	$RaceUI/RaceResults.visible = false


func update_lap_display() -> void:
	$RaceUI/LapMargin/LapText.text = "LAP: %d/%d" % [current_lap, total_laps]

func _hide_race_countdown() -> void:
	$RaceUI/RaceStartTimer/RaceCountDown.visible = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("PAUSE"):
		toggle_main_menu_visibility()
	
	if get_tree().paused:
		$RaceUI/RaceStartTimer/RaceCountDown.text = str(int(timer.time_left) + 1)
	
	if racing:
		update_time()

func _item_collected(item: GameManager.Item):
	match item:
		GameManager.Item.JUMP:
			$RaceUI/ItemMargin/Item.texture = load("res://assets/textures/items/jump.png")
		GameManager.Item.BOOST:
			$RaceUI/ItemMargin/Item.texture = load("res://assets/textures/items/boost.png")
		GameManager.Item.SPEEDUP:
			$RaceUI/ItemMargin/Item.texture = load("res://assets/textures/items/speed.png")

func _item_used():
	$RaceUI/ItemMargin/Item.texture = null

func _race_started(player_id: int):
	if player_id == multiplayer.get_unique_id():
		racing = true
		current_lap = 1
		update_lap_display()

func _lap_completed(player_id: int, lap_number: int):
	if player_id == multiplayer.get_unique_id():
		current_lap = min(lap_number + 1, total_laps)
		update_lap_display()

func _race_completed(player_id: int, time: float):
	if racing and player_id == multiplayer.get_unique_id():
		racing = false
		update_time()
	elif racing:
		placement = placement + 1

func toggle_main_menu_visibility() -> void:
	$MainMenu.visible = not $MainMenu.visible

# this crashes when host leaves to menu 
func update_time() -> void:
	var finish_time = Time.get_ticks_msec() / 1000.0
	var race_time = finish_time - RaceManager.player_race_times[multiplayer.get_unique_id()]
	$RaceUI/TimeMargin/Time.text = str(race_time).pad_decimals(3)


func _start_race_for_player(peer_id: int) -> void:
	# Make sure to start the race timer after the player is fully set up
	get_tree().paused = false
	RaceManager.player_spawned(peer_id)

func _on_race_completed(player_id: int, _time: float) -> void:
	if player_id == multiplayer.get_unique_id():
		# This is our player who finished
		racing = false

func _on_race_times_received(times: Dictionary) -> void:
	update_race_results(times)
	if NetworkManager.local or times.size() == 1:
		show_race_results()
	else:
		var all_players_finished = true
		for player_id in NetworkManager.lobby_members:
			if not times.has(player_id):
				all_players_finished = false
				break
		if all_players_finished:
			show_race_results()

func update_race_results(times: Dictionary) -> void:
	var sorted_times = RaceManager.get_sorted_race_times()
	var results_list = $RaceUI/RaceResults/VBoxContainer/ResultsList
	
	for child in results_list.get_children():
		child.queue_free()
	
	# Add results for each player
	for i in range(sorted_times.size()):
		var result = sorted_times[i]
		var result_item = result_item_scene.instantiate()
		
		var position_text = ""
		match i:
			0: position_text = "1st"
			1: position_text = "2nd"
			2: position_text = "3rd"
			_: position_text = str(i + 1) + "th"
			
		result_item.get_node("Position").text = position_text
		result_item.get_node("PlayerName").text = result.player_name
		result_item.get_node("Time").text = str(result.time).pad_decimals(2) + "s"
		
		# Highlight the current player
		if result.player_id == multiplayer.get_unique_id():
			result_item.get_node("Position").add_theme_color_override("font_color", Color(1, 0.5, 0, 1))
			result_item.get_node("PlayerName").add_theme_color_override("font_color", Color(1, 0.5, 0, 1))
			result_item.get_node("Time").add_theme_color_override("font_color", Color(1, 0.5, 0, 1))
		
		results_list.add_child(result_item)

func show_race_results() -> void:
	if race_results_visible:
		return
	race_results_visible = true
	$RaceUI/RaceResults.visible = true
	
	# Make sure the return button has correct text and visibility
	var return_button = $RaceUI/RaceResults/VBoxContainer/ReturnToLobby
	if return_button:
		if NetworkManager.local:
			return_button.text = "Return to Menu"
			return_button.visible = true  # Always visible in singleplayer
		else:
			return_button.text = "Return to Lobby"
			return_button.visible = multiplayer.is_server()  # Only visible for host
			
func _on_return_to_lobby_pressed() -> void:
	if NetworkManager.local:
		# For singleplayer, return directly to the main menu
		get_tree().change_scene_to_file("res://scenes/menus/menu.tscn")
	else:
		# For multiplayer, if we're host, use the existing exit to lobby functionality
		if multiplayer.is_server():
			# This will use the existing logic in gui_menu.gd to synchronize all clients
			$MainMenu/ButtonsMenu/MenuLayers._on_exit_to_lobby_pressed()
