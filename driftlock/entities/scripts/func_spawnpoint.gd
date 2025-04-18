@tool
extends Node3D

@export var spawn_id: int = 1
@export_enum("Forward (+Z)", "Right (+X)", "Backward (-Z)", "Left (-X)", "Up (+Y)", "Down (-Y)") var exit_direction: int = 0:
	set(value):
		exit_direction = value
		update_arrow_direction()
@export var show_debug_visual: bool = true:
	set(value):
		show_debug_visual = value
		if debug_visual:
			debug_visual.visible = value if not Engine.is_editor_hint() else true

var debug_visual: MeshInstance3D

func spawn_player(player: Node3D) -> void:
	if player == null:
		return
		
	# First make sure the player is in the scene tree
	if not player.is_inside_tree():
		printerr("Cannot spawn player - not in scene tree")
		return
	
	# Position the player
	player.global_position = global_position
	
	# Set rotation based on exit direction
	player.global_rotation.y = global_rotation.y
	
	# Set looking direction if available
	if player.has_method("set_looking_direction"):
		player.set_looking_direction(get_exit_direction_vector())
	elif "looking_direction" in player:
		player.looking_direction = get_exit_direction_vector()
		
	print("Spawned player at position: " + str(global_position))

func _func_godot_apply_properties(props: Dictionary) -> void:
	if "spawn_id" in props:
		spawn_id = props["spawn_id"] as int
	if "exit_direction" in props:
		exit_direction = props["exit_direction"] as int
	if "show_debug_visual" in props:
		show_debug_visual = props["show_debug_visual"] as bool

func _ready() -> void:
	if Engine.is_editor_hint():
		create_debug_visual()
		return
		
	create_debug_visual()
	# Register this spawn point with RaceManager
	RaceManager.register_spawn_point(spawn_id, global_position, get_exit_direction_vector(), global_rotation.y)
	
	print("Spawn point registered with ID: ", spawn_id)

func create_debug_visual() -> void:
	if debug_visual:
		debug_visual.queue_free()
	
	debug_visual = MeshInstance3D.new()
	
	# Create a simple arrow pointing in the exit direction
	var arrow_mesh = CylinderMesh.new()
	arrow_mesh.top_radius = 0.0
	arrow_mesh.bottom_radius = 0.3
	arrow_mesh.height = 1.0
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 1.0, 0.0)  # Yellow
	material.emission_enabled = true
	material.emission = Color(1.0, 1.0, 0.0)
	material.emission_energy_multiplier = 2.0
	arrow_mesh.material = material
	
	debug_visual.mesh = arrow_mesh
	
	add_child(debug_visual)
	debug_visual.visible = show_debug_visual
	
	update_arrow_direction()

func update_arrow_direction() -> void:
	if not debug_visual:
		return
	
	debug_visual.rotation = Vector3.ZERO
	
	match exit_direction:
		0: # Forward (+Z)
			debug_visual.rotation_degrees = Vector3(90, 0, 0)
		1: # Right (+X)
			debug_visual.rotation_degrees = Vector3(0, 0, -90)
		2: # Backward (-Z)
			debug_visual.rotation_degrees = Vector3(-90, 0, 0)
		3: # Left (-X)
			debug_visual.rotation_degrees = Vector3(0, 0, 90)
		4: # Up (+Y)
			debug_visual.rotation_degrees = Vector3(0, 0, 0)
		5: # Down (-Y)
			debug_visual.rotation_degrees = Vector3(180, 0, 0)

func get_exit_direction_vector() -> Vector3:
	var base_direction: Vector3
	
	match exit_direction:
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

	return global_transform.basis * base_direction

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		if debug_visual:
			debug_visual.visible = true
