extends CharacterBody3D

@onready var camera = $Camera3D

# How fast the player moves in meters per second.
@export var speed = 30
# How fast the player turns, in... radians per... I don't know.
@export var rot_speed = 3
# The downward acceleration when in the air, in meters per second squared.
@export var fall_acceleration = 75

@export var looking_direction = Vector3(1, 0, 0)

enum DriftMode {NONE, WAITING, ANIM_LEFT, ANIM_RIGHT, LEFT, RIGHT}
var drifting = DriftMode.NONE
const drift_startup = 0.5

var rpc_position = Vector3.ZERO

func _ready() -> void:
	camera.current = is_multiplayer_authority()

func _physics_process(delta):
	if is_multiplayer_authority():
		if Input.is_action_just_pressed("DRIFT"):
			drifting = DriftMode.WAITING
		
		if !Input.is_action_pressed("DRIFT") and (DriftMode.LEFT or DriftMode.RIGHT):
			drifting = DriftMode.NONE
		
		var left_turn_mod = 1.0
		var right_turn_mod = 1.0
		var percent_max_speed = Vector3(velocity.x, 0, velocity.z).length()/speed
		match drifting:
			DriftMode.LEFT, DriftMode.ANIM_LEFT:
				left_turn_mod = lerp(1.0, 1.5, percent_max_speed)
				right_turn_mod = 0.5
			DriftMode.RIGHT, DriftMode.ANIM_RIGHT:
				right_turn_mod = lerp(1.0, 1.5, percent_max_speed)
				left_turn_mod = 0.5
			
		
		if Input.is_action_just_pressed("WAVE"):
			$fox/AnimationPlayer.play("wave")
			rpc("remote_emote")
			
		var target_velocity = Vector3.ZERO
		#
		if Input.is_action_pressed("RIGHT"):
			if drifting == DriftMode.WAITING and !Input.is_action_pressed("LEFT"):
				drifting = DriftMode.ANIM_RIGHT
				get_tree().create_timer(drift_startup, true, true).timeout.connect(drift_right)
			
			looking_direction = lerp(looking_direction, looking_direction.rotated(Vector3.UP, -1), delta*rot_speed*right_turn_mod)
			looking_direction = looking_direction.normalized()
		if Input.is_action_pressed("LEFT"):
			if drifting == DriftMode.WAITING and !Input.is_action_pressed("RIGHT"):
				drifting = DriftMode.ANIM_LEFT
				get_tree().create_timer(drift_startup, true, true).timeout.connect(drift_left)
				
			looking_direction = lerp(looking_direction, looking_direction.rotated(Vector3.UP, 1), delta*rot_speed*left_turn_mod)
			looking_direction = looking_direction.normalized()
		if Input.is_action_pressed("DOWN"):
			target_velocity = -looking_direction*speed
		if Input.is_action_pressed("UP"):
			target_velocity = looking_direction*speed
		
		global_rotation.y = atan2(looking_direction.x, looking_direction.z)

		# Vertical Velocity
		if not is_on_floor(): # If in the air, fall towards the floor. Literally gravity
			target_velocity.y = target_velocity.y - (fall_acceleration * delta)
			target_velocity.x = velocity.x
			target_velocity.z = velocity.z

		# Moving the Character
		#if(prev_velocity.dot(target_velocity) < 0):
			#prev_velocity = Vector3.ZERO
		
		velocity = lerp(velocity, target_velocity, delta*1.0)

		move_and_slide()
			
		rpc("set_remote_position", global_position, global_rotation.y)
	else:
		global_position = global_position.lerp(rpc_position, 0.1)

func drift_left():
	drifting = DriftMode.LEFT
func drift_right():
	drifting = DriftMode.RIGHT

@rpc("unreliable")
func set_remote_position(new_position, new_rotation):
	rpc_position = new_position
	global_rotation.y = new_rotation
	

@rpc("reliable")
func remote_emote():
	$fox/AnimationPlayer.play("wave")
