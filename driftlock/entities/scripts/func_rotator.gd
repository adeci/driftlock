@tool
extends AnimatableBody3D

@export var targetname: String = ""
@export var axis: Vector3 = Vector3(0, 1, 0)
@export var degrees: float = 180
@export var speed: float = 1
@export var active_time: float = 5
@export var loop_pause: float = 0
@export var looped: bool = false
@export var smooth: bool = false
@export var spin: bool = false

const TRANS_TYPE: Tween.TransitionType = Tween.TRANS_QUAD
var tween: Tween = null
var is_active: bool = false

func _func_godot_apply_properties(props: Dictionary) -> void:
	if "targetname" in props:
		targetname = props["targetname"] as String
	if "axis" in props:
		axis = props["axis"] as Vector3
	if "degrees" in props:
		degrees = props["degrees"] as float
	if "speed" in props:
		speed = props["speed"] as float
	if "active_time" in props:
		active_time = props["active_time"] as float
	if "loop_pause" in props:
		loop_pause = props["loop_pause"] as float
	if "looped" in props:
		looped = props["looped"] as bool
	if "smooth" in props:
		smooth = props["smooth"] as bool
	if "spin" in props:
		spin = props["spin"] as bool

func _init() -> void:
	sync_to_physics = true

func _ready() -> void:
	GameManager.button_pressed.connect(_on_button_pressed)
	speed = 1 / speed
	if spin:
		activate_spin()
	elif looped:
		activate_looped()

func _on_button_pressed(target: String) -> void:
	if (targetname == target and not is_active):
		activate_timed()

func activate_spin() -> void:
	is_active = true
	var amount: Vector3 = 360 * axis
	tween = create_tween().set_loops()
	tween.tween_property(self, "rotation_degrees", amount, speed).as_relative()

func activate_looped() -> void:
	is_active = true
	var amount: Vector3 = degrees * axis
	tween = create_tween().set_loops()
	if smooth:
		tween.tween_property(self, "rotation_degrees", amount, speed).as_relative().set_trans(TRANS_TYPE)
		tween.tween_interval(loop_pause)
		tween.tween_property(self, "rotation_degrees", -amount, speed).as_relative().set_trans(TRANS_TYPE)
		tween.tween_interval(loop_pause)
	else:
		tween.tween_property(self, "rotation_degrees", amount, speed).as_relative()
		tween.tween_interval(loop_pause)
		tween.tween_property(self, "rotation_degrees", -amount, speed).as_relative()
		tween.tween_interval(loop_pause)

func activate_timed() -> void:
	is_active = true
	var amount: Vector3 = degrees * axis
	tween = create_tween()
	if smooth:
		tween.tween_property(self, "rotation_degrees", amount, speed).as_relative().set_trans(TRANS_TYPE)
		tween.tween_interval(active_time)
		tween.tween_property(self, "rotation_degrees", -amount, speed).as_relative().set_trans(TRANS_TYPE)
		tween.tween_callback(func (): is_active = false)
	else:
		tween.tween_property(self, "rotation_degrees", amount, speed).as_relative()
		tween.tween_interval(active_time)
		tween.tween_property(self, "rotation_degrees", -amount, speed).as_relative()
		tween.tween_callback(func (): is_active = false)
