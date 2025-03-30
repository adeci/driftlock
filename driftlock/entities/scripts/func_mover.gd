@tool
extends AnimatableBody3D

@export var targetname: String = ""
@export var translation: Vector3 = Vector3(0, 0, 0)
@export var speed: float = 1
@export var looped: bool = false

var start: Vector3 = Vector3.ZERO
var end: Vector3 = Vector3.ZERO
var direction: int = 1

func _func_godot_apply_properties(props: Dictionary):
	if "targetname" in props:
		targetname = props["targetname"] as String
	if "translation" in props:
		translation = props["translation"] as Vector3
	if "speed" in props:
		speed = props["speed"] as float
	if "looped" in props:
		looped = props["looped"] as bool

func _init() -> void:
	add_to_group("func_mover")
	sync_to_physics = false

func _ready() -> void:
	GameManager.set_targetname(self, targetname)
	start = position
	end = start

func _physics_process(delta: float) -> void:
	position.x += direction * signf(translation.x) * minf(abs(translation.x) * delta * speed, abs(end.x - position.x))
	position.y += direction * signf(translation.y) * minf(abs(translation.y) * delta * speed, abs(end.y - position.y))
	position.z += direction * signf(translation.z) * minf(abs(translation.z) * delta * speed, abs(end.z - position.z))
	if (looped and position.is_equal_approx(start)):
		await get_tree().create_timer(1).timeout
		play_motion()
	if (looped and position.is_equal_approx(start + translation)):
		await get_tree().create_timer(1).timeout
		reverse_motion()

func use() -> void:
	play_motion()

func play_motion() -> void:
	end = start + translation
	direction = 1

func reverse_motion() -> void:
	end = start
	direction = -1
