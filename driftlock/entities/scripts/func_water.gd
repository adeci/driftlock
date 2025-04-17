@tool
extends Area3D

# Exported properties that match with the FGD definitions
@export var buoyancy: float = 0.8
@export var water_color: Color = Color(0.0, 0.4, 0.6, 0.5)
@export var water_foam: bool = false
@export var water_wave_height: float = 0.1
@export var water_wave_speed: float = 1.0

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
	if "water_foam" in props:
		water_foam = props["water_foam"] as bool
	if "water_wave_height" in props:
		water_wave_height = props["water_wave_height"] as float
	if "water_wave_speed" in props:
		water_wave_speed = props["water_wave_speed"] as float
	
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
		if body is CharacterBody3D:
			apply_water_physics(body, delta)

func apply_water_physics(body: CharacterBody3D, delta: float) -> void:
	# Calculate how submerged the body is
	var body_center = body.global_position
	var water_top = global_position.y
	
	# For collision shapes, try to estimate the water volume extents
	for child in get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			water_top += child.shape.size.y * 0.5
			break
	
	var submerged_factor = clamp((water_top - body_center.y) / 2.0, 0.0, 1.0)
	
	# Allow player to move freely in water
	# Apply reduced gravity (buoyancy) but don't completely negate it
	if "fall_acceleration" in body:
		# Reduce gravity effect rather than reversing it, so player can still dive down
		var reduced_gravity = body.fall_acceleration * (1.0 - buoyancy * submerged_factor)
		body.velocity.y -= reduced_gravity * delta
		
		# Apply slight downward force to help player sink
		if Input.is_action_pressed("DOWN") and body.is_multiplayer_authority():
			body.velocity.y -= 5.0 * delta
		
		# Apply slight upward force to help player rise
		if Input.is_action_pressed("UP") and body.is_multiplayer_authority():
			body.velocity.y += 5.0 * delta
	
	# Set water state on the player if it has the property
	if "is_in_water" in body:
		body.is_in_water = true

func _on_body_entered(body: Node) -> void:
	if body is CharacterBody3D:
		bodies_in_water[body] = true
		
		# Add a splash effect
		create_splash_effect(body.global_position)

func _on_body_exited(body: Node) -> void:
	if bodies_in_water.has(body):
		bodies_in_water.erase(body)
		
		# Add exit splash effect
		create_splash_effect(body.global_position)
		
		# Reset water state
		if "is_in_water" in body:
			body.is_in_water = false

func create_splash_effect(pos_world: Vector3) -> void:
	# Skip splash effect in editor
	if Engine.is_editor_hint():
		return
		
	# Make sure we're in the scene tree before creating effects
	if !is_inside_tree():
		return
	
	# Create a simple particle effect for the splash
	var splash = GPUParticles3D.new()
	var particle_mesh = SphereMesh.new()
	particle_mesh.radius = 0.05
	particle_mesh.height = 0.1
	splash.mesh = particle_mesh
	
	splash.emitting = true
	splash.one_shot = true
	splash.explosiveness = 0.8
	splash.amount = 20
	splash.lifetime = 0.6
	
	# Set up particle material
	var particle_material = ParticleProcessMaterial.new()
	particle_material.direction = Vector3(0, 1, 0)
	particle_material.spread = 45.0
	particle_material.gravity = Vector3(0, -9.8, 0)
	particle_material.initial_velocity_min = 1.0
	particle_material.initial_velocity_max = 3.0
	
	splash.process_material = particle_material
	
	# Set position and add to scene
	splash.global_position = Vector3(pos_world.x, global_position.y, pos_world.z)
	get_parent().add_child(splash)
	
	# Auto-remove after effect completes
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(splash):
		splash.queue_free()

func setup_water_material() -> void:
	# Create or update the water material
	if not water_material:
		water_material = ShaderMaterial.new()
		water_material.shader = load("res://assets/shaders/water_shader.gdshader")
	
	# Set shader parameters
	water_material.set_shader_parameter("water_color", water_color)
	water_material.set_shader_parameter("wave_height", water_wave_height)
	water_material.set_shader_parameter("wave_speed", water_wave_speed)
	water_material.set_shader_parameter("foam_enabled", water_foam)
	water_material.set_shader_parameter("time", time_passed)
	
	# Apply material to the mesh instances
	for child in get_children():
		if child is MeshInstance3D:
			child.material_override = water_material
