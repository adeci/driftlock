@tool
extends StaticBody3D

@export var targetname: String = ""
@export var translation: Vector3 = Vector3(0, 0, 0)
@export var speed: float = 1
@export var active_time: float = 5
@export var loop_pause: float = 0
@export var looped: bool = false

enum State {READY, ACTIVE}
var state = State.READY
var moving: bool = false
var start: Vector3 = Vector3.ZERO
var end: Vector3 = Vector3.ZERO
var trans_x: float = 0
var trans_y: float = 0
var trans_z: float = 0
var timer: Timer = Timer.new()

func _func_godot_apply_properties(props: Dictionary) -> void:
	if "targetname" in props:
		targetname = props["targetname"] as String
	if "translation" in props:
		translation = props["translation"] as Vector3
	if "speed" in props:
		speed = props["speed"] as float
	if "active_time" in props:
		active_time = props["active_time"] as float
	if "loop_pause" in props:
		loop_pause = props["loop_pause"] as float
	if "looped" in props:
		looped = props["looped"] as bool

func _ready() -> void:
	GameManager.button_pressed.connect(_on_button_pressed)
	add_child(timer)
	timer.one_shot = true
	timer.autostart = false
	timer.wait_time = active_time
	timer.timeout.connect(_on_timer_timeout)
	start = position
	end = position + translation
	trans_x = translation.x
	trans_y = translation.y
	trans_z = translation.z
	if looped:
		moving = true
		state = State.ACTIVE

func _on_timer_timeout() -> void:
	state = State.READY
	if moving:
		reverse_direction()
	else:
		moving = true

func _on_button_pressed(target: String) -> void:
	if (targetname == target):
		activate()

func _physics_process(delta: float) -> void:
	if moving:
		if (sign(trans_x)*(position.x + trans_x * delta * speed) >= sign(trans_x)*end.x
		and sign(trans_y)*(position.y + trans_x * delta * speed) >= sign(trans_y)*end.y
		and sign(trans_z)*(position.z + trans_x * delta * speed) >= sign(trans_z)*end.z):
			position = end
			reverse_direction()
			if looped:
				pause_movement(loop_pause)
			else:
				moving = false
		else:
			position.x += trans_x * delta * speed
			position.y += trans_y * delta * speed
			position.z += trans_z * delta * speed

func pause_movement(time: float) -> void:
	if (time > 0):
		moving = false
		await get_tree().create_timer(time).timeout
		moving = true

func reverse_direction() -> void:
	trans_x = -trans_x
	trans_y = -trans_y
	trans_z = -trans_z
	var temp: Vector3 = end
	end = start
	start = temp

func activate() -> void:
	if moving or state == State.ACTIVE:
		return
	timer.start()
	moving = true
	state = State.ACTIVE
