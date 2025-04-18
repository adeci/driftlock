@tool
extends Area3D

# Exported properties that match with the FGD definitions
@export var buoyancy: float = 0.8
@export var water_color: Color = Color(0.0, 0.4, 0.6, 0.5)
@export var water_wave_height: float = 0.1
@export var water_wave_speed: float = 1.0
@export var movement_slowdown: float = 0.6

# Internal variables
var bodies_in_water: Dictionary = {}
var water_material: ShaderMaterial
var time_passed: float = 0.0

# Called when node enters scene tree
func _ready() -> void:
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Create shader material for the water
	setup_water_material()

# Apply properties from the map file
func _func_godot_apply_properties(props: Dictionary) -> void:
	if "buoyancy" in props:
		buoyancy = props["buoyancy"] as float
	if "water_color" in props:
		water_color = props["water_color"] as Color
	if "water_wave_height" in props:
		water_wave_height = props["water_wave_height"] as float
	if "water_wave_speed" in props:
		water_wave_speed = props["water_wave_speed"] as float
	if "movement_slowdown" in props:
		movement_slowdown = props["movement_slowdown"] as float

	# Update material with new properties
	if is_inside_tree():
		setup_water_material()

func _physics_process(delta: float) -> void:
	time_passed += delta

	# Update water shader time parameter
	if water_material:
		water_material.set_shader_parameter("time", time_passed)

	# Apply water physics to bodies in water
	for body in bodies_in_water:
		if body is CharacterBody3D and body.is_multiplayer_authority():
			apply_water_physics(body, delta)

func apply_water_physics(body: CharacterBody3D, delta: float) -> void:
	# Instead of changing gravity completely, we just reduce its effect
	if "fall_acceleration" in body:
		# Apply reduced gravity (buoyancy factor reduces the effect of gravity)
		var fall_effect = body.fall_acceleration * (1.0 - buoyancy) * delta
		
		# Only reduce downward velocity, don't slow down upward velocity
		if body.velocity.y < 0:
			body.velocity.y = max(body.velocity.y - fall_effect, body.velocity.y * 0.95)
		else:
			body.velocity.y -= fall_effect * 0.5  # Reduce upward velocity less

	# Slow down horizontal movement in water
	var horizontal_velocity = Vector2(body.velocity.x, body.velocity.z)
	if horizontal_velocity.length_squared() > 0.01:
		# Apply gradual slowdown rather than instant reduction
		horizontal_velocity = horizontal_velocity.lerp(Vector2.ZERO, (1.0 - movement_slowdown) * delta * 3.0)
		body.velocity.x = horizontal_velocity.x
		body.velocity.z = horizontal_velocity.y
	
	# Set a property on the body so the camera shader knows we're underwater
	if "is_in_water" in body:
		body.is_in_water = true
	else:
		# If the property doesn't exist, add it
		body.set("is_in_water", true)

func _on_body_entered(body: Node) -> void:
	if body is CharacterBody3D:
		bodies_in_water[body] = true

func _on_body_exited(body: Node) -> void:
	if bodies_in_water.has(body):
		bodies_in_water.erase(body)

		# Reset water state
		if "is_in_water" in body:
			body.is_in_water = false

func setup_water_material() -> void:
	# Create or update the water material
	if not water_material:
		water_material = ShaderMaterial.new()
		water_material.shader = load("res://assets/shaders/water_shader.gdshader")

	# Set shader parameters
	water_material.set_shader_parameter("water_color", water_color)
	water_material.set_shader_parameter("wave_height", water_wave_height)
	water_material.set_shader_parameter("wave_speed", water_wave_speed)
	water_material.set_shader_parameter("time", time_passed)

	# Apply material to the mesh instances
	for child in get_children():
		if child is MeshInstance3D:
			child.material_override = water_material
