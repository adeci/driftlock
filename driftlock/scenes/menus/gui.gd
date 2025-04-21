extends MarginContainer

var racing: bool
var placement: int
var current_lap: int = 1
var total_laps: int = 3

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not multiplayer.is_server() or NetworkManager.local:
		$MainMenu/ButtonsMenu/MenuLayers/Layer1/Buttons/Seperator/BottomButtons/ExitToLobby.visible = false

	$MainMenu.visible = false
	$RaceUI.visible = true

	self.visible = true
	
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


func toggle_layer(extra_arg_0):
	pass # Replace with function body.
