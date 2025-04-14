@tool
extends Area3D
@export var show_debug_arrows: bool = true:
	set(value):
		show_debug_arrows = value
		if debug_arrow:
			debug_arrow.visible = value if not Engine.is_editor_hint() else true
@export var targetname: String = ""
@export var target: String = ""
@export var delay: float = 0.5
@export var offset_distance: float = 1.0
@export_enum("Forward (+Z)", "Right (+X)", "Backward (-Z)", "Left (-X)", "Up (+Y)", "Down (-Y)") var exit_direction: int = 0:
	set(value):
		exit_direction = value
		update_arrow_direction()
var cooldown: bool = false
var debug_arrow: MeshInstance3D
var bounds: AABB

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

func _ready() -> void:
	if Engine.is_editor_hint():
		create_debug_arrow()
		return
	body_entered.connect(_on_body_entered)
	add_to_group("teleporter")
	create_debug_arrow()

func _func_godot_build_complete() -> void:
	calculate_bounds()
	update_arrow_direction()

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

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		if debug_arrow:
			debug_arrow.visible = true
	else:
		if debug_arrow:
			debug_arrow.visible = show_debug_arrows

func _on_body_entered(body: Node3D) -> void:
	if cooldown or target.is_empty() or Engine.is_editor_hint():
		return
	if not body is CharacterBody3D:
		return
	var destination = get_destination_teleporter()
	if destination == null:
		print("Error: Destination teleporter not found for " + targetname + " targeting " + target)
		return
	cooldown = true
	teleport_body(body, destination)
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

func teleport_body(body: CharacterBody3D, destination: Node3D) -> void:
	var forward_dir = get_exit_direction_vector(destination)
	var base_pos = get_exit_position(destination)
	var teleport_position = base_pos + (forward_dir * offset_distance)

	body.global_position = teleport_position
	
	if "looking_direction" in body:
		body.looking_direction = forward_dir
		body.global_rotation.y = atan2(forward_dir.x, forward_dir.z)

	if body.velocity.length() > 0:
		var speed = body.velocity.length()
		body.velocity = forward_dir * speed
