extends MarginContainer

var racing: bool
var placement: int
var current_lap: int = 1
var total_laps: int = 3


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	
	if not multiplayer.is_server() or NetworkManager.local:
		$MainMenu/ButtonsMenu/MenuLayers/Layer1/Buttons/Seperator/BottomButtons/ExitToLobby.visible = false

	$MainMenu.visible = false
	$RaceUI.visible = true

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

func update_lap_display() -> void:
	$RaceUI/LapMargin/LapText.text = "LAP: %d/%d" % [current_lap, total_laps]

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("PAUSE"):
		toggle_main_menu_visibility()
		
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
		match placement:
			1:
				$RaceUI/PlacementMargin/Placement.text = "1st!"
			2:
				$RaceUI/PlacementMargin/Placement.text = "2nd!"
			3:
				$RaceUI/PlacementMargin/Placement.text = "3rd!"
			_:
				$RaceUI/PlacementMargin/Placement.text = str(placement) + "th"
		$RaceUI/RaceCompleteMargin/RaceComplete.visible = true
	elif racing:
		placement = placement + 1

func toggle_main_menu_visibility() -> void:
	$MainMenu.visible = not $MainMenu.visible

func update_time() -> void:
	var finish_time = Time.get_ticks_msec() / 1000.0
	var race_time = finish_time - RaceManager.player_race_times[multiplayer.get_unique_id()]
	$RaceUI/TimeMargin/Time.text = str(race_time).pad_decimals(3)
