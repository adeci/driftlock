extends MarginContainer

@export var master_slider: HSlider
@export var sfx_slider: HSlider
@export var music_slider: HSlider

func _ready() -> void:
	# Initialize sliders with current volumes
	master_slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))) * 100
	sfx_slider.value = SoundManager.sfx_volume * 100
	music_slider.value = SoundManager.music_volume * 100
	
	# Connect signals
	master_slider.value_changed.connect(_on_master_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	$PanelContainer/MarginContainer/VBoxContainer/CloseButton.pressed.connect(_on_close_pressed)
	
	# Set proper process mode to make sure it works when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Initially hide the control
	visible = false

func _input(event: InputEvent) -> void:
	# Only process input when visible
	if not visible:
		return
		
	# Close the volume menu when Escape is pressed
	if event.is_action_pressed("PAUSE"):
		visible = false
		get_viewport().set_input_as_handled()

func _on_master_volume_changed(value: float) -> void:
	var linear_volume = value / 100.0
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(linear_volume))

func _on_sfx_volume_changed(value: float) -> void:
	var linear_volume = value / 100.0
	SoundManager.set_sfx_volume(linear_volume)

func _on_music_volume_changed(value: float) -> void:
	var linear_volume = value / 100.0
	SoundManager.set_music_volume(linear_volume)

func _on_close_pressed() -> void:
	visible = false
	SoundManager.play_sound(SoundManager.SoundCatalog.BUTTON1)
	
func show_control() -> void:
	# Ensure this control is the top-most in its parent
	if get_parent():
		get_parent().move_child(self, get_parent().get_child_count() - 1)
	
	# Show the control
	visible = true
	
	# Focus the first slider
	master_slider.grab_focus()
