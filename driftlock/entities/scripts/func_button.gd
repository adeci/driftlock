@tool
extends Area3D

@export var target: String = ""
@export var axis: Vector3 = Vector3(0, -1, 0)
@export var depth: float = 0.8
@export var speed: float = 8

var is_pressed: bool = false
var base_translation: Vector3 = Vector3.ZERO
var release_delay: float = 0.1

var overlaps: int = 0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)

func _func_godot_apply_properties(props: Dictionary):
	if "target" in props:
		target = props["target"] as String
	if "axis" in props:
		axis = props["axis"] as Vector3
	if "depth" in props:
		depth = props["depth"] as float
	if "speed" in props:
		speed = props["speed"] as float

func _init() -> void:
	connect("body_shape_entered", body_shape_entered)
	connect("body_shape_exited", body_shape_exited)

func _enter_tree() -> void:
	base_translation = position

func _process(delta: float) -> void:
	var target_position = base_translation + (axis * (depth if is_pressed else 0.0))
	position = position.lerp(target_position, speed * delta)

func body_shape_entered(_body_id, body: Node, _body_shape_idx: int, _self_shape_idx: int) -> void:
	if body is StaticBody3D:
		return
	if overlaps == 0 and body is CharacterBody3D:
		SoundManager.play_sound(random_button_sound(), false, body.global_position)
		press()
	overlaps += 1

func body_shape_exited(_body_id, body: Node, _body_shape_idx: int, _self_shape_idx: int) -> void:
	if body is StaticBody3D:
		return
	overlaps -= 1
	if overlaps == 0:
		if release_delay == 0:
			release()
		elif release_delay > 0:
			await get_tree().create_timer(release_delay).timeout
			release()

func press() -> void:
	if is_pressed:
		return
	is_pressed = true
	emit_pressed()

func emit_pressed() -> void:
	if target.is_empty():
		return
	GameManager.button_pressed.emit(target)

func release() -> void:
	if not is_pressed:
		return
	is_pressed = false
	await get_tree().create_timer(release_delay).timeout
	
func random_button_sound() -> SoundManager.SoundCatalog:
	var sound_options = [
		SoundManager.SoundCatalog.BUTTON1,
		SoundManager.SoundCatalog.BUTTON2,
		SoundManager.SoundCatalog.BUTTON3
	]
	var selected_sound = sound_options[randi() % sound_options.size()]
	return selected_sound
