extends MarginContainer

var racing: bool
var placement: int

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$MainMenu.visible = false
	$RaceUI.visible = true
	self.visible = true
	
	racing = false
	RaceManager.race_started.connect(_race_started)
	RaceManager.race_completed.connect(_race_completed)
	
	placement = 1
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("PAUSE"):
		toggle_main_menu_visibility()
		
	if racing:
		update_time()

func _race_started(player_id: int):
	if player_id == multiplayer.get_unique_id():
		racing = true
		
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
	elif racing:
		placement = placement + 1

func toggle_main_menu_visibility() -> void:
	$MainMenu.visible = not $MainMenu.visible

func update_time() -> void:
	var finish_time = Time.get_ticks_msec() / 1000.0
	var race_time = finish_time - RaceManager.player_race_times[multiplayer.get_unique_id()]
	$RaceUI/TimeMargin/Time.text = str(race_time).pad_decimals(3)
