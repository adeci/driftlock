@tool
extends Area3D
@export var show_debug_arrows: bool = false:
	set(value):
		show_debug_arrows = value
		if debug_arrow:
			debug_arrow.visible = value if not Engine.is_editor_hint() else false
@export var targetname: String = ""
@export var target: String = ""
@export var delay: float = 0.5
@export var offset_distance: float = 1.0
@export_enum("Forward (+Z)", "Right (+X)", "Backward (-Z)", "Left (-X)", "Up (+Y)", "Down (-Y)") var exit_direction: int = 0:
	set(value):
		exit_direction = value
		update_arrow_direction()

# Portal shader properties
@export_category("Portal Appearance")
@export var portal_color: Color = Color(0.5, 0.0, 0.8, 0.7):
	set(value):
		portal_color = value
		_update_shader_params()
@export var portal_edge_color: Color = Color(0.9, 0.2, 1.0, 0.9):
	set(value):
		portal_edge_color = value
		_update_shader_params()
@export var portal_speed: float = 1.0:
	set(value):
		portal_speed = value
		_update_shader_params()
@export var portal_distortion: float = 0.5:
	set(value):
		portal_distortion = value
		_update_shader_params()
@export var portal_scale: float = 3.0:
	set(value):
		portal_scale = value
		_update_shader_params()
@export var edge_intensity: float = 0.5:
	set(value):
		edge_intensity = value
		_update_shader_params()

var cooldown: bool = false
var debug_arrow: MeshInstance3D
var portal_shader_material: ShaderMaterial
var bounds: AABB
var time: float = 0.0
var mesh_instance: MeshInstance3D

func _func_godot_apply_properties(props: Dictionary) -> void:
	if "targetname" in props:
		targetname = props["targetname"] as String
	if "target" in props:
		target = props["target"] as String
	if "delay" in props:
		delay = props["delay"] as float
	if "offset_distance" in props:
		offset_distance = props["offset_distance"] as float
	if "exit_direction" in props:
		exit_direction = props["exit_direction"] as int
	if "show_debug_arrows" in props:
		show_debug_arrows = props["show_debug_arrows"] as bool
	if "portal_color" in props:
		portal_color = props["portal_color"] as Color
	if "portal_edge_color" in props:
		portal_edge_color = props["portal_edge_color"] as Color
	if "portal_speed" in props:
		portal_speed = props["portal_speed"] as float
	if "portal_distortion" in props:
		portal_distortion = props["portal_distortion"] as float
	if "portal_scale" in props:
		portal_scale = props["portal_scale"] as float
	if "edge_intensity" in props:
		edge_intensity = props["edge_intensity"] as float

func _ready() -> void:
	if Engine.is_editor_hint():
		create_debug_arrow()
		return
	
	body_entered.connect(_on_body_entered)
	add_to_group("teleporter")
	create_debug_arrow()
	
	# Create the shader material
	setup_portal_shader()
	find_and_apply_shader()
	
	# Schedule a delayed shader application as a fallback
	call_deferred("delayed_shader_application")

func delayed_shader_application() -> void:
	# Wait for a short delay to ensure entity is fully built
	await get_tree().create_timer(0.5).timeout
	find_and_apply_shader()

func find_and_apply_shader() -> void:
	mesh_instance = find_mesh_instance()
	if mesh_instance:
		print("Found mesh instance for teleporter: ", name)
		apply_shader_to_mesh()
	else:
		print("Looking for mesh instance for teleporter: ", name)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if debug_arrow:
			debug_arrow.visible = true
	else:
		if debug_arrow:
			debug_arrow.visible = show_debug_arrows
			
	# Update shader time parameter
	time += delta
	if portal_shader_material and mesh_instance and mesh_instance.mesh:
		portal_shader_material.set_shader_parameter("time", time)

func _func_godot_build_complete() -> void:
	calculate_bounds()
	update_arrow_direction()
	
	# Find the mesh instance created by func_godot
	mesh_instance = find_mesh_instance()
	
	if mesh_instance:
		print("Found mesh instance during build_complete: ", mesh_instance.name)
		# Apply our shader to the mesh instance
		apply_shader_to_mesh()
	else:
		print("Warning: Could not find mesh instance during build_complete")
		# Schedule a delayed attempt
		call_deferred("delayed_find_mesh")
		
func delayed_find_mesh() -> void:
	await get_tree().create_timer(0.2).timeout
	mesh_instance = find_mesh_instance()
	if mesh_instance:
		print("Found mesh instance after delay: ", mesh_instance.name)
		apply_shader_to_mesh()
	else:
		print("Still could not find mesh instance after delay")
		
func print_children_hierarchy(node: Node = null, indent: String = "") -> void:
	if node == null:
		node = self
		print("Children hierarchy for teleporter: ", name)
	
	print(indent + node.name + " - " + node.get_class())
	indent += "  "
	for child in node.get_children():
		print_children_hierarchy(child, indent)

func find_mesh_instance() -> MeshInstance3D:
	# First, look for a MeshInstance3D child with "mesh_instance" in the name
	for child in get_children():
		if child is MeshInstance3D and "mesh_instance" in child.name:
			return child
	
	# If not found, check for any MeshInstance3D
	for child in get_children():
		if child is MeshInstance3D:
			return child
			
	# If still not found, recursively search all children
	return find_mesh_in_children(self)
	
func find_mesh_in_children(node: Node) -> MeshInstance3D:
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
		
		var result = find_mesh_in_children(child)
		if result != null:
			return result
	
	return null


func setup_portal_shader() -> void:
	portal_shader_material = ShaderMaterial.new()
	var shader = load("res://assets/shaders/portal_shader.gdshader")
	if not shader:
		print("Error: Portal shader not found at res://assets/shaders/portal_shader.gdshader")
		return
	
	print("Portal shader loaded successfully")
	portal_shader_material.shader = shader
	_update_shader_params()

func apply_shader_to_mesh() -> void:
	if not mesh_instance:
		print("Cannot apply shader: No mesh instance")
		return
		
	if not portal_shader_material:
		print("Cannot apply shader: No shader material")
		return
	
	print("Applying shader to mesh: ", mesh_instance.name)
	
	# Get the original mesh
	var original_mesh = mesh_instance.mesh
	if not original_mesh:
		print("Cannot apply shader: Mesh instance has no mesh")
		return
	
	print("Original mesh has ", original_mesh.get_surface_count(), " surfaces")
	
	# Create a copy of the mesh to avoid modifying the original
	var mesh_copy = original_mesh.duplicate()
	
	# Apply our shader material to all surfaces
	for i in range(mesh_copy.get_surface_count()):
		print("Applying shader to surface ", i)
		mesh_copy.surface_set_material(i, portal_shader_material)
	
	# Set the modified mesh
	mesh_instance.mesh = mesh_copy
	
	# Configure transparency and make sure it's visible
	mesh_instance.visible = true
	mesh_instance.transparency = 0.5
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	print("Shader applied successfully to mesh")

func calculate_bounds() -> void:
	bounds = AABB()
	var first = true
	
	for child in get_children():
		if child is CollisionShape3D and child.shape:
			var shape_aabb: AABB
			
			if child.shape is BoxShape3D:
				var box = child.shape as BoxShape3D
				shape_aabb = AABB(-box.size/2, box.size)
			elif child.shape is ConvexPolygonShape3D:
				var verts = child.shape.points
				if verts.size() > 0:
					var min_point = verts[0]
					var max_point = verts[0]
					for v in verts:
						min_point.x = min(min_point.x, v.x)
						min_point.y = min(min_point.y, v.y)
						min_point.z = min(min_point.z, v.z)
						max_point.x = max(max_point.x, v.x)
						max_point.y = max(max_point.y, v.y)
						max_point.z = max(max_point.z, v.z)
					shape_aabb = AABB(min_point, max_point - min_point)
				
			shape_aabb = shape_aabb.grow(0.1)
			
			if first:
				bounds = shape_aabb
				first = false
			else:
				bounds = bounds.merge(shape_aabb)
	
	if first:
		bounds = AABB(Vector3(-0.5, -0.5, -0.5), Vector3(1, 1, 1))

func create_debug_arrow() -> void:
	if debug_arrow:
		debug_arrow.queue_free()

	debug_arrow = MeshInstance3D.new()
	var arrow_mesh = CylinderMesh.new()
	arrow_mesh.top_radius = 0.0
	arrow_mesh.bottom_radius = 0.2
	arrow_mesh.height = 0.5
	debug_arrow.mesh = arrow_mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0, 0.5, 1, 1)
	material.emission_enabled = true
	material.emission = Color(0, 0.5, 1, 1)
	material.emission_energy_multiplier = 2.0
	arrow_mesh.material = material

	if bounds.size == Vector3.ZERO:
		calculate_bounds()
	update_arrow_direction()
	debug_arrow.visible = show_debug_arrows if not Engine.is_editor_hint() else true
	add_child(debug_arrow)

func _update_shader_params() -> void:
	if portal_shader_material:
		portal_shader_material.set_shader_parameter("portal_color", portal_color)
		portal_shader_material.set_shader_parameter("portal_edge_color", portal_edge_color)
		portal_shader_material.set_shader_parameter("portal_speed", portal_speed)
		portal_shader_material.set_shader_parameter("portal_distortion", portal_distortion)
		portal_shader_material.set_shader_parameter("portal_scale", portal_scale)
		portal_shader_material.set_shader_parameter("edge_intensity", edge_intensity)
		portal_shader_material.set_shader_parameter("time", time)

func update_arrow_direction() -> void:
	if not debug_arrow:
		return
	
	if bounds.size == Vector3.ZERO:
		calculate_bounds()
	
	debug_arrow.rotation = Vector3.ZERO
	
	var center = bounds.position + bounds.size/2
	var extents = bounds.size/2
	var arrow_pos = Vector3.ZERO
	
	match exit_direction:
		0: # Forward (+Z)
			arrow_pos = Vector3(center.x, center.y, center.z + extents.z + 0.1)
			debug_arrow.rotation_degrees = Vector3(90, 0, 0)
		1: # Right (+X)
			arrow_pos = Vector3(center.x + extents.x + 0.1, center.y, center.z)
			debug_arrow.rotation_degrees = Vector3(0, 0, -90)
		2: # Backward (-Z)
			arrow_pos = Vector3(center.x, center.y, center.z - extents.z - 0.1)
			debug_arrow.rotation_degrees = Vector3(-90, 0, 0)
		3: # Left (-X)
			arrow_pos = Vector3(center.x - extents.x - 0.1, center.y, center.z)
			debug_arrow.rotation_degrees = Vector3(0, 0, 90)
		4: # Up (+Y)
			arrow_pos = Vector3(center.x, center.y + extents.y + 0.1, center.z)
			debug_arrow.rotation_degrees = Vector3(0, 0, 0)
		5: # Down (-Y)
			arrow_pos = Vector3(center.x, center.y - extents.y - 0.1, center.z)
			debug_arrow.rotation_degrees = Vector3(180, 0, 0)
	debug_arrow.position = arrow_pos

func _on_body_entered(body: Node3D) -> void:
	if cooldown or target.is_empty() or Engine.is_editor_hint():
		return
	if not body is CharacterBody3D:
		return
		
	var destination = get_destination_teleporter()
	if destination == null:
		print("Error: Destination teleporter not found for " + targetname + " targeting " + target)
		return
	var selected_sound = random_teleport_sound()
	SoundManager.play_sound(selected_sound, true, global_position)
	
	cooldown = true
	teleport_body(body, destination, selected_sound)
	
	await get_tree().create_timer(delay).timeout
	cooldown = false

func get_destination_teleporter() -> Node:
	var teleporters = get_tree().get_nodes_in_group("teleporter")
	for teleporter in teleporters:
		if teleporter != self and teleporter.targetname == target:
			return teleporter
			
	return null

func get_exit_position(dest_teleporter: Node3D) -> Vector3:
	if dest_teleporter.bounds.size == Vector3.ZERO:
		dest_teleporter.calculate_bounds()

	var center = dest_teleporter.bounds.position + dest_teleporter.bounds.size/2
	var extents = dest_teleporter.bounds.size/2
	

	var exit_pos = Vector3.ZERO
	match dest_teleporter.exit_direction:
		0: # Forward (+Z)
			exit_pos = Vector3(center.x, center.y, center.z + extents.z)
		1: # Right (+X)
			exit_pos = Vector3(center.x + extents.x, center.y, center.z)
		2: # Backward (-Z)
			exit_pos = Vector3(center.x, center.y, center.z - extents.z)
		3: # Left (-X)
			exit_pos = Vector3(center.x - extents.x, center.y, center.z)
		4: # Up (+Y)
			exit_pos = Vector3(center.x, center.y + extents.y, center.z)
		5: # Down (-Y)
			exit_pos = Vector3(center.x, center.y - extents.y, center.z)
			
	# Convert to global space
	return dest_teleporter.to_global(exit_pos)

func get_exit_direction_vector(dest_teleporter: Node3D) -> Vector3:
	var base_direction: Vector3
	
	match dest_teleporter.exit_direction:
		0: # Forward (+Z)
			base_direction = Vector3(0, 0, 1)
		1: # Right (+X)
			base_direction = Vector3(1, 0, 0)
		2: # Backward (-Z)
			base_direction = Vector3(0, 0, -1)
		3: # Left (-X)
			base_direction = Vector3(-1, 0, 0)
		4: # Up (+Y)
			base_direction = Vector3(0, 1, 0)
		5: # Down (-Y)
			base_direction = Vector3(0, -1, 0)

	return dest_teleporter.global_transform.basis * base_direction

func teleport_body(body: CharacterBody3D, destination: Node3D, sound_category: SoundManager.SoundCatalog = -1) -> void:
	var forward_dir = get_exit_direction_vector(destination)
	var base_pos = get_exit_position(destination)
	var teleport_position = base_pos + (forward_dir * offset_distance)
	var old_position = body.global_position
	body.global_position = teleport_position
	
	if sound_category != -1:
		SoundManager.play_sound(sound_category, true, teleport_position)
	
	if "looking_direction" in body:
		body.looking_direction = forward_dir
		body.global_rotation.y = atan2(forward_dir.x, forward_dir.z)

	if body.velocity.length() > 0:
		var speed = body.velocity.length()
		body.velocity = forward_dir * speed

func random_teleport_sound() -> SoundManager.SoundCatalog:
	var sound_options = [
		SoundManager.SoundCatalog.TELE1,
		SoundManager.SoundCatalog.TELE2,
		SoundManager.SoundCatalog.TELE3
	]
	var selected_sound = sound_options[randi() % sound_options.size()]
	return selected_sound
