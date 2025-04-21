extends MarginContainer

@export var master_slider: HSlider
@export var sfx_slider: HSlider
@export var music_slider: HSlider

func _ready() -> void:
	master_slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))) * 100
	sfx_slider.value = SoundManager.sfx_volume * 100
	music_slider.value = SoundManager.music_volume * 100
	master_slider.value_changed.connect(_on_master_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)

func _on_master_volume_changed(value: float) -> void:
	var linear_volume = value / 100.0
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(linear_volume))

func _on_sfx_volume_changed(value: float) -> void:
	var linear_volume = value / 100.0
	SoundManager.set_sfx_volume(linear_volume)
	SoundManager.play_sound(SoundManager.SoundCatalog.BUTTON1)

func _on_music_volume_changed(value: float) -> void:
	var linear_volume = value / 100.0
	SoundManager.set_music_volume(linear_volume)

func _on_close_pressed() -> void:
	visible = false
