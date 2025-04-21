@tool
extends Area3D

@export var respawn_time: float = 10
@export_category("Visual Settings")
@export var item_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var flow_speed: float = 4.0
@export var color_saturation: float = 1.0
@export var color_brightness: float = 1.2
@export var pulse_intensity: float = 0.3
@export var rainbow_scale: float = 2.0
@export var rim_strength: float = 0.7
@export var glow_strength: float = 0.9
@export var transparency: float = 0.6

var timer: Timer = Timer.new()
var item_shader: ShaderMaterial
var time_passed: float = 0.0

func _func_godot_apply_properties(props: Dictionary):
	if "respawn_time" in props:
		respawn_time = props["respawn_time"] as float

func _init() -> void:
	connect("body_shape_entered", body_shape_entered)

func _ready() -> void:
	add_child(timer)
	timer.one_shot = true
	timer.autostart = false
	timer.wait_time = respawn_time
	timer.timeout.connect(_on_timer_timeout)
	
	setup_shader()

func _process(delta: float) -> void:
	time_passed += delta
	
	if item_shader:
		item_shader.set_shader_parameter("time", time_passed)

func setup_shader() -> void:
	item_shader = ShaderMaterial.new()
	
	var shader_path = "res://assets/shaders/item_box_shader.gdshader"
	if ResourceLoader.exists(shader_path):
		var shader_resource = load(shader_path)
		if shader_resource:
			item_shader.shader = shader_resource
		else:
			print("Error: Failed to load shader resource from ", shader_path)
	else:
		print("Error: Shader file not found at ", shader_path)
		return
	
	item_shader.set_shader_parameter("flow_speed", flow_speed)
	item_shader.set_shader_parameter("color_saturation", color_saturation)
	item_shader.set_shader_parameter("color_brightness", color_brightness)
	item_shader.set_shader_parameter("pulse_intensity", pulse_intensity)
	item_shader.set_shader_parameter("rainbow_scale", rainbow_scale)
	item_shader.set_shader_parameter("rim_strength", rim_strength)
	item_shader.set_shader_parameter("glow_strength", glow_strength)
	item_shader.set_shader_parameter("transparency", transparency)
	item_shader.set_shader_parameter("time", time_passed)
	
	var mesh_instance = find_mesh_instance()
	if mesh_instance:
		mesh_instance.material_override = item_shader

func find_mesh_instance() -> MeshInstance3D:
	for child in get_children():
		if child is MeshInstance3D:
			return child
	return null

func body_shape_entered(_body_id, body: Node, _body_shape_idx: int, _self_shape_idx: int) -> void:
	if timer.is_stopped() and body is CharacterBody3D and body.has_method("set_item"):
		if body.is_multiplayer_authority():
			SoundManager.play_sound(SoundManager.SoundCatalog.ITEM_PICKUP)
		else:
			SoundManager.play_sound(SoundManager.SoundCatalog.ITEM_PICKUP, true, global_position)
		body.set_item(GameManager.generateItem())
		visible = false
		timer.start()

func _on_timer_timeout() -> void:
	visible = true
