extends Camera3D

@export var follow_target: CharacterBody3D
@export var look_target: Node3D

var look_speed: float
var target_speed: float

var follow_displacement = Vector3(1, 0, 0)
var prev_look_target: Vector3

enum CameraMode {PLAYER, FIXED}
var mode = CameraMode.PLAYER

# Underwater effect variables
var underwater_effect: ColorRect
var underwater_material: ShaderMaterial
var in_water: bool = false
var underwater_transition: float = 0.0
var transition_speed: float = 3.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	look_speed = 20.0
	target_speed = 20.0

	# Create underwater effect
	setup_underwater_effect()

func setup_underwater_effect() -> void:
	# Create a ColorRect that covers the entire viewport
	underwater_effect = ColorRect.new()
	underwater_effect.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Create shader material
	underwater_material = ShaderMaterial.new()
	underwater_material.shader = load("res://assets/shaders/underwater_effect.gdshader")

	# Load noise texture if it exists
	var noise_texture_path = "res://assets/textures/perlin_noise.tres"
	if ResourceLoader.exists(noise_texture_path):
		underwater_material.set_shader_parameter("perlin_noise", load(noise_texture_path))

	underwater_material.set_shader_parameter("distortion_strength", 0.02)
	underwater_material.set_shader_parameter("water_darkness", 0.2)
	underwater_material.set_shader_parameter("wave_speed", 1.5)
	underwater_material.set_shader_parameter("water_tint", Color(0.0, 0.1, 0.3, 0.3))
	underwater_material.set_shader_parameter("time", 0.0)

	underwater_effect.material = underwater_material

	# Initially invisible
	underwater_effect.modulate = Color(1, 1, 1, 0)

	# Add to camera as child
	add_child(underwater_effect)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("CAMERA"):
		if mode == CameraMode.PLAYER:
			mode = CameraMode.FIXED
		else:
			mode = CameraMode.PLAYER

	# Check if player is in water
	if follow_target and "is_in_water" in follow_target:
		in_water = follow_target.is_in_water
	else:
		in_water = false

	# Update underwater effect
	update_underwater_effect(delta)

func update_underwater_effect(delta: float) -> void:
	# Update time for shader animation
	if underwater_material:
		underwater_material.set_shader_parameter("time", Time.get_ticks_msec() / 1000.0)

	# Smooth transition into/out of water
	if in_water:
		underwater_transition = min(underwater_transition + delta * transition_speed, 1.0)
	else:
		underwater_transition = max(underwater_transition - delta * transition_speed, 0.0)

	# Apply transition to effect visibility
	if underwater_effect:
		underwater_effect.modulate = Color(1, 1, 1, underwater_transition)

func _physics_process(delta: float) -> void:
	if mode == CameraMode.PLAYER:
		look_speed = lerp(look_speed, target_speed, delta*10.0)
		follow_player(delta)
	else:
		global_position = Vector3(-16.775, 5.48, 15.966)
		global_rotation_degrees = Vector3(-4.2, -49.3, 0.1)

func follow_player(delta: float):
	follow_displacement = -3*follow_target.looking_direction + Vector3(0, 2, 0)

	#collide with walls (jank)
	#var cam_col = follow_target.get_node("cameracollider")
	#cam_col.global_position = follow_target.global_position + Vector3(0,0.5,0)
	#cam_col.target_position = Vector3(0, 2, -3)
	var target_pos
	#if cam_col.is_colliding():
	#target_pos = cam_col.get_collision_point() - 0.05 * cam_col.target_position
	#else:
	#target_pos = follow_target.global_position + follow_displacement
	target_pos = follow_target.global_position + follow_displacement
	global_position = global_position.lerp(target_pos, delta * 20.0)
	prev_look_target = lerp(prev_look_target, look_target.global_position+Vector3(0,0.5,0), delta*look_speed)
	look_at(prev_look_target)

func set_target_speed(speed: float):
	target_speed = speed
