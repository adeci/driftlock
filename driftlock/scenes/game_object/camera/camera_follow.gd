extends Camera3D

@export var follow_target: CharacterBody3D
@export var look_target: Node3D

var follow_displacement = Vector3(1, 0, 0)
var prev_look_target: Vector3

enum CameraMode {PLAYER, FIXED}
var mode = CameraMode.PLAYER

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _process(delta: float) -> void:
	if(Input.is_action_just_pressed("CAMERA")):
		if mode == CameraMode.PLAYER:
			mode = CameraMode.FIXED
		else :
			mode = CameraMode.PLAYER

func _physics_process(delta: float) -> void:
	if(mode == CameraMode.PLAYER):
		follow_player(delta)
	else:
		global_position = Vector3(-16.775, 5.48, 15.966)
		global_rotation_degrees = Vector3(-4.2, -49.3, 0.1)

func follow_player(delta: float):
	follow_displacement = -3*follow_target.looking_direction + Vector3(0, 2, 0)
	global_position = global_position.lerp(follow_target.global_position + follow_displacement, delta * 20.0)
	prev_look_target = lerp(prev_look_target, look_target.global_position+Vector3(0,0.5,0), delta*20.0)
	look_at(prev_look_target)
