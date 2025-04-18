extends CharacterBody3D

@onready var camera: Camera3D = $Camera3D

# How fast the player moves in meters per second.
@export var speed = 30
# How fast the player turns, in... radians per... I don't know.
@export var rot_speed = 3
# The downward acceleration when in the air, in meters per second squared.
@export var fall_acceleration = 75

@export var looking_direction = Vector3(1, 0, 0)

enum DriftMode {NONE, WAITING, ANIM_LEFT, ANIM_RIGHT, LEFT, RIGHT}
enum Animations {IDLE, DRIFTLEFT, DRIFTRIGHT, RUN, DRIFTCANCEL}
var drifting = DriftMode.NONE
const drift_startup = 0.5
const jump_velocity = 10
const fov_multiplier = 1.3
const speedup_multiplier = 1.5
const speedup_time = 10
var speedup_timer = Timer.new()
var held_item = null

var in_race: bool = false
var race_started: bool = false
var respawning: bool = false
var respawn_timer: Timer
var invincibility_timer: Timer
var original_collision_layer: int
var original_collision_mask: int

var rpc_position = Vector3.ZERO

func _ready() -> void:
	camera.current = is_multiplayer_authority()
	add_child(speedup_timer)
	speedup_timer.one_shot = true
	speedup_timer.autostart = false
	speedup_timer.wait_time = speedup_time

	# Setup respawn timers
	respawn_timer = Timer.new()
	respawn_timer.one_shot = true
	respawn_timer.wait_time = 2.0  # Delay time to hold at respawn
	respawn_timer.autostart = false
	respawn_timer.timeout.connect(_on_respawn_timer_timeout)
	add_child(respawn_timer)

	invincibility_timer = Timer.new()
	invincibility_timer.one_shot = true
	invincibility_timer.wait_time = 5.0  # Time player is non-collidable
	invincibility_timer.autostart = false
	invincibility_timer.timeout.connect(_on_invincibility_timer_timeout)
	add_child(invincibility_timer)

	# Store original collision settings
	original_collision_layer = collision_layer
	original_collision_mask = collision_mask

	# Register with RaceManager if we're authoritative
	if is_multiplayer_authority():
		RaceManager.register_player(get_multiplayer_authority())
		RaceManager.respawn_started.connect(_on_respawn_started)


func _physics_process(delta):
	if is_multiplayer_authority():

		if not respawning:
			if Input.is_action_just_pressed("RESPAWN"):
				request_respawn()

			if Input.is_action_just_pressed("START_RACE") and not race_started:
				race_started = true
				RaceManager.start_race(get_multiplayer_authority())

		if Input.is_action_just_pressed("DRIFT") and drifting == DriftMode.NONE:
			drifting = DriftMode.WAITING

		if !Input.is_action_pressed("DRIFT") and (drifting == DriftMode.LEFT or drifting == DriftMode.RIGHT):
			drifting = DriftMode.NONE
			$Camera3D.set_target_speed(20.0)
			play_animation.rpc(Animations.DRIFTCANCEL)
			$AnimationTree.set("parameters/drift_left_seek/seek_request", 0.0)
			$AnimationTree.set("parameters/drift_right_seek/seek_request", 0.0)
			$AnimationTree.set("parameters/drift_left_add/add_amount", 0.0)
			$AnimationTree.set("parameters/drift_right_add/add_amount", 0.0)
			$AnimationTree.set("parameters/drift_blend/blend_amount", 0.0)

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

		if Input.is_action_just_pressed("USE"):
			use_item()
		if Input.is_action_just_pressed("WAVE"):
			#$fox/AnimationPlayer.play("wave")
			if percent_max_speed < 0.01:
				$AnimationTree.set("parameters/wave_shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
				rpc("remote_emote")
			else:
				$AnimationTree.set("parameters/wave_shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)

		var target_velocity = Vector3.ZERO
		#
		if Input.is_action_pressed("RIGHT"):
			if drifting == DriftMode.WAITING and !Input.is_action_pressed("LEFT"):
				drifting = DriftMode.ANIM_RIGHT
				$Camera3D.set_target_speed(15.0)
				play_animation.rpc(Animations.DRIFTRIGHT)
				$AnimationTree.set("parameters/drift_right_seek/seek_request", 0.0)
				$AnimationTree.set("parameters/drift_blend/blend_amount", 1.0)
				$AnimationTree.set("parameters/drift_right_add/add_amount", 1.0)
				get_tree().create_timer(drift_startup, true, true).timeout.connect(drift_right)

			looking_direction = lerp(looking_direction, looking_direction.rotated(Vector3.UP, -1), delta*rot_speed*right_turn_mod)
			looking_direction = looking_direction.normalized()
		if Input.is_action_pressed("LEFT"):
			if drifting == DriftMode.WAITING and !Input.is_action_pressed("RIGHT"):
				drifting = DriftMode.ANIM_LEFT
				$Camera3D.set_target_speed(15.0)
				play_animation.rpc(Animations.DRIFTLEFT)
				$AnimationTree.set("parameters/drift_left_seek/seek_request", 0.0)
				$AnimationTree.set("parameters/drift_blend/blend_amount", 1.0)
				$AnimationTree.set("parameters/drift_left_add/add_amount", 1.0)
				get_tree().create_timer(drift_startup, true, true).timeout.connect(drift_left)

			looking_direction = lerp(looking_direction, looking_direction.rotated(Vector3.UP, 1), delta*rot_speed*left_turn_mod)
			looking_direction = looking_direction.normalized()
		if Input.is_action_pressed("DOWN"):
			target_velocity = -looking_direction*speed
		if Input.is_action_pressed("UP"):
			target_velocity = looking_direction*speed
			play_animation.rpc(Animations.RUN)
			$AnimationTree.set("parameters/run_amount/blend_amount", min(1.0, percent_max_speed*2))
		else :
			play_animation.rpc(Animations.IDLE)
			var current = $AnimationTree.get("parameters/run_amount/blend_amount")
			$AnimationTree.set("parameters/run_amount/blend_amount", lerp(current, 0.0, 12*delta))

		if respawning:
			# You can add visual effects here if needed
			# to indicate player is respawning/collisions off for a bit
			pass

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

func set_looking_direction(new_direction: Vector3) -> void:
	new_direction.y = 0
	new_direction = new_direction.normalized()
	looking_direction = new_direction
	global_rotation.y = atan2(looking_direction.x, looking_direction.z)
	global_rotation.y = atan2(looking_direction.x, looking_direction.z)

@rpc("unreliable")
func set_remote_position(new_position, new_rotation):
	rpc_position = new_position
	global_rotation.y = new_rotation


# Handle respawn request
func request_respawn() -> void:
	if is_multiplayer_authority() and not respawning:
		RaceManager.start_respawn(get_multiplayer_authority())

# Respawn started callback
func _on_respawn_started(player_id: int) -> void:
	if player_id != get_multiplayer_authority():
		return
	respawning = true
	# Freeze player movement
	velocity = Vector3.ZERO
	# Get respawn position and rotation from RaceManager
	var respawn_pos = RaceManager.get_respawn_position(player_id)
	var respawn_rot = RaceManager.get_respawn_rotation(player_id)

	if respawn_pos != Vector3.ZERO:
		# Teleport to respawn point
		global_position = respawn_pos

		# Set the rotation and looking direction
		global_rotation.y = respawn_rot
		looking_direction = Vector3(sin(respawn_rot), 0, cos(respawn_rot))

		print("Player respawned at: ", respawn_pos)

		# Start the hold timer
		respawn_timer.start()
	else:
		# No respawn point, just complete immediately
		_on_respawn_timer_timeout()

# When respawn hold time is finished
func _on_respawn_timer_timeout() -> void:
	if not is_multiplayer_authority():
		return

	# Make player non-collidable with other players
	# Assuming player-player collision is on layer/mask bit 1
	collision_layer &= ~2  # Turn off bit 1 in collision layer
	collision_mask &= ~2   # Turn off bit 1 in collision mask

	# Player can move now
	respawning = false

	# Notify RaceManager respawn is complete
	RaceManager.complete_respawn(get_multiplayer_authority())

	# Start invincibility timer
	invincibility_timer.start()

# When invincibility period ends
func _on_invincibility_timer_timeout() -> void:
	if not is_multiplayer_authority():
		return
	# Restore original collision settings
	collision_layer = original_collision_layer
	collision_mask = original_collision_mask
	print("Player invincibility ended")


# Network Animation Handler
@rpc("unreliable")
func play_animation(animation):
	match animation:
		Animations.IDLE:
			var current = $AnimationTree.get("parameters/run_amount/blend_amount")
			$AnimationTree.set("parameters/run_amount/blend_amount", lerp(current, 0.0, 12*get_physics_process_delta_time()))
		Animations.DRIFTCANCEL:
			$AnimationTree.set("parameters/drift_left_seek/seek_request", 0.0)
			$AnimationTree.set("parameters/drift_right_seek/seek_request", 0.0)
			$AnimationTree.set("parameters/drift_left_add/add_amount", 0.0)
			$AnimationTree.set("parameters/drift_right_add/add_amount", 0.0)
			$AnimationTree.set("parameters/drift_blend/blend_amount", 0.0)
		Animations.RUN:
			var current = $AnimationTree.get("parameters/run_amount/blend_amount")
			$AnimationTree.set("parameters/run_amount/blend_amount", lerp(current, 1.0, 0.1))
		Animations.DRIFTLEFT:
			$AnimationTree.set("parameters/drift_left_seek/seek_request", 0.0)
			$AnimationTree.set("parameters/drift_blend/blend_amount", 1.0)
			$AnimationTree.set("parameters/drift_left_add/add_amount", 1.0)
		Animations.DRIFTRIGHT:
			$AnimationTree.set("parameters/drift_right_seek/seek_request", 0.0)
			$AnimationTree.set("parameters/drift_blend/blend_amount", 1.0)
			$AnimationTree.set("parameters/drift_right_add/add_amount", 1.0)


@rpc("reliable")
func remote_emote():
	$fox/AnimationPlayer.play("wave")

func set_item(item: GameManager.Item) -> void:
	held_item = item

func use_item() -> void:
	var item = held_item
	held_item = null
	match item:
		null:
			print("No item!")
		GameManager.Item.SPEEDUP:
			print("Used speedup!")
			speedup()
		GameManager.Item.BOOST:
			print("Used boost!")
			boost()
		GameManager.Item.JUMP:
			print("Used jump!")
			jump()

func speedup() -> void:
	if speedup_timer.is_stopped():
		var old_speed = speed
		var old_fov = camera.fov
		speed *= speedup_multiplier
		camera.fov *= fov_multiplier
		speedup_timer.start()
		await speedup_timer.timeout
		speed = old_speed
		camera.fov = old_fov
	else:
		speedup_timer.start()

func boost() -> void:
	velocity.x = speedup_multiplier * speed * looking_direction.x
	velocity.z = speedup_multiplier * speed * looking_direction.z

func jump() -> void:
	velocity.y = jump_velocity
