extends Node

var steam_status: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	initialize_steam()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	Steam.run_callbacks()

func initialize_steam() -> void:
	var initialize_response: Dictionary = Steam.steamInitEx()
	if initialize_response["status"] == 0:
		steam_status = true
	print("Did Steam initialize?: %s " % initialize_response)
	
