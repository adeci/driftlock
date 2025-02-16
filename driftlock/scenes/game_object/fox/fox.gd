extends CharacterBody3D

# How fast the player moves in meters per second.
@export var speed = 30
# How fast the player turns, in... radians per... I don't know.
@export var rot_speed = 3
# The downward acceleration when in the air, in meters per second squared.
@export var fall_acceleration = 75

@export var looking_direction = Vector3(1, 0, 0)

var target_velocity = Vector3.ZERO
var prev_velocity = Vector3.ZERO

func _physics_process(delta):
<<<<<<< HEAD
	if is_multiplayer_authority():
		if Input.is_action_just_pressed("WAVE"):
			$fox/AnimationPlayer.play("wave")
		
		var direction = Vector3.ZERO

		if Input.is_action_pressed("RIGHT"):
			direction.x += 1
		if Input.is_action_pressed("LEFT"):
			direction.x -= 1
		if Input.is_action_pressed("DOWN"):
			direction.z += 1
		if Input.is_action_pressed("UP"):
			direction.z -= 1

		if direction != Vector3.ZERO:
			direction = direction.normalized()

		# Ground Velocity
		target_velocity.x = direction.x * speed
		target_velocity.z = direction.z * speed
=======
	if Input.is_action_just_pressed("WAVE"):
		$fox/AnimationPlayer.play("wave")

	target_velocity = Vector3.ZERO
	
	if Input.is_action_pressed("RIGHT"):
		looking_direction = lerp(looking_direction, looking_direction.rotated(Vector3.UP, -1), delta*rot_speed)
		looking_direction = looking_direction.normalized()
	if Input.is_action_pressed("LEFT"):
		looking_direction = lerp(looking_direction, looking_direction.rotated(Vector3.UP, 1), delta*rot_speed)
		looking_direction = looking_direction.normalized()
	if Input.is_action_pressed("DOWN"):
		target_velocity = -looking_direction*speed
	if Input.is_action_pressed("UP"):
		target_velocity = looking_direction*speed
	
	global_rotation.y = atan2(looking_direction.x, looking_direction.z)
>>>>>>> main

		# Vertical Velocity
		if not is_on_floor(): # If in the air, fall towards the floor. Literally gravity
			target_velocity.y = target_velocity.y - (fall_acceleration * delta)

<<<<<<< HEAD
		# Moving the Character
		velocity = target_velocity
		move_and_slide()
		
		rpc("set_remote_position", global_position)
		
@rpc("unreliable")
func set_remote_position(position):
	global_position = position
=======
	# Moving the Character
	#if(prev_velocity.dot(target_velocity) < 0):
		#prev_velocity = Vector3.ZERO
	velocity = lerp(prev_velocity, target_velocity, delta*1.0)
	prev_velocity = velocity
	move_and_slide()
	
>>>>>>> main
