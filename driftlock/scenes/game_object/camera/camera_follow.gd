extends Camera3D

@export var follow_target: CharacterBody3D
@export var look_target: Node3D

var look_speed: float
var target_speed: float

var follow_displacement = Vector3(1, 0, 0)
var prev_look_target: Vector3

enum CameraMode {PLAYER, FIXED}
var mode = CameraMode.PLAYER

var underwater_effect: ColorRect
var underwater_material: ShaderMaterial
var in_water: bool = false
var underwater_transition: float = 0.0
var transition_speed: float = 3.0

var post_process_layer: CanvasLayer
var post_process_rect: ColorRect
var shader_material: ShaderMaterial
var time_passed: float = 0.0

func _ready() -> void:
	look_speed = 20.0
	target_speed = 20.0

	setup_underwater_effect()
	if follow_target and follow_target.is_multiplayer_authority():
		setup_post_process_effect()

func setup_underwater_effect() -> void:
	underwater_effect = ColorRect.new()
	underwater_effect.set_anchors_preset(Control.PRESET_FULL_RECT)

	underwater_material = ShaderMaterial.new()
	underwater_material.shader = load("res://assets/shaders/underwater_effect.gdshader")

	var noise_texture_path = "res://assets/textures/perlin_noise.tres"
	if ResourceLoader.exists(noise_texture_path):
		underwater_material.set_shader_parameter("perlin_noise", load(noise_texture_path))

	underwater_material.set_shader_parameter("distortion_strength", 0.02)
	underwater_material.set_shader_parameter("water_darkness", 0.2)
	underwater_material.set_shader_parameter("wave_speed", 1.5)
	underwater_material.set_shader_parameter("water_tint", Color(0.0, 0.1, 0.3, 0.3))
	underwater_material.set_shader_parameter("time", 0.0)

	underwater_effect.material = underwater_material

	underwater_effect.modulate = Color(1, 1, 1, 0)
	add_child(underwater_effect)

func setup_post_process_effect() -> void:
	post_process_layer = CanvasLayer.new()
	post_process_layer.layer = -1
	add_child(post_process_layer)
	
	post_process_rect = ColorRect.new()
	post_process_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	post_process_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_process_layer.add_child(post_process_rect)
	
	shader_material = ShaderMaterial.new()
	shader_material.shader = load("res://assets/shaders/crt_effect.gdshader")
	
	shader_material.set_shader_parameter("pixel_size", 4.0)
	shader_material.set_shader_parameter("color_bits", 4.0)
	shader_material.set_shader_parameter("dither_strength", 0.15)
	shader_material.set_shader_parameter("scanlines_opacity", 0.12)
	shader_material.set_shader_parameter("vignette_strength", 0.15)
	shader_material.set_shader_parameter("vignette_size", 0.75)
	shader_material.set_shader_parameter("chrom_aberration", 0.5)
	shader_material.set_shader_parameter("noise_strength", 0.01)
	shader_material.set_shader_parameter("time", 0.0)
	
	post_process_rect.material = shader_material

func _process(delta: float) -> void:
	time_passed += delta
	
	if shader_material:
		shader_material.set_shader_parameter("time", time_passed)
	
	if Input.is_action_just_pressed("CAMERA"):
		if mode == CameraMode.PLAYER:
			mode = CameraMode.FIXED
		else:
			mode = CameraMode.PLAYER

	if follow_target and "is_in_water" in follow_target:
		in_water = follow_target.is_in_water
	else:
		in_water = false

	update_underwater_effect(delta)

func update_underwater_effect(delta: float) -> void:
	if underwater_material:
		underwater_material.set_shader_parameter("time", Time.get_ticks_msec() / 1000.0)

	if in_water:
		underwater_transition = min(underwater_transition + delta * transition_speed, 1.0)
	else:
		underwater_transition = max(underwater_transition - delta * transition_speed, 0.0)

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

	var target_pos = follow_target.global_position + follow_displacement
	global_position = global_position.lerp(target_pos, delta * 20.0)
	prev_look_target = lerp(prev_look_target, look_target.global_position+Vector3(0,0.5,0), delta*look_speed)
	look_at(prev_look_target)

func set_target_speed(speed: float):
	target_speed = speed
