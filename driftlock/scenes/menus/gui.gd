extends MarginContainer


signal exit_to_lobby


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not multiplayer.is_server() or NetworkManager.local:
		$MainMenu/ButtonsMenu/MenuLayers/Layer1/Buttons/Seperator/BottomButtons/ExitToLobby.visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("PAUSE"):
		toggle_visibility()

func toggle_visibility() -> void:
	self.visible = not self.visible
