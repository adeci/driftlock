@tool
extends Node3D

@export var spawn_id: int = 1
@export_enum("Forward (+Z)", "Right (+X)", "Backward (-Z)", "Left (-X)", "Up (+Y)", "Down (-Y)") var exit_direction: int = 0:
	set(value):
		exit_direction = value
@export var show_debug_visual: bool = false:
	set(value):
		show_debug_visual = value
		if debug_visual:
			debug_visual.visible = value if not Engine.is_editor_hint() else false

var debug_visual: MeshInstance3D

func spawn_player(player: Node3D) -> void:
	if player == null:
		return
	if not player.is_inside_tree():
		printerr("Cannot spawn player - not in scene tree")
		return
	player.global_position = global_position
	var direction = get_exit_direction_vector()
	var look_rotation = atan2(direction.x, direction.z)
	player.global_rotation.y = look_rotation
	if player.has_method("set_looking_direction"):
		player.set_looking_direction(direction)
	elif "looking_direction" in player:
		player.looking_direction = direction
	print("Spawned player at position: " + str(global_position) + " with rotation: " + str(look_rotation))

func _func_godot_apply_properties(props: Dictionary) -> void:
	if "spawn_id" in props:
		spawn_id = props["spawn_id"] as int
	if "exit_direction" in props:
		exit_direction = props["exit_direction"] as int
	if "show_debug_visual" in props:
		show_debug_visual = props["show_debug_visual"] as bool

func _ready() -> void:
	var direction = get_exit_direction_vector()
	var look_rotation = atan2(direction.x, direction.z)
	RaceManager.register_spawn_point(spawn_id, global_position, direction, look_rotation)
	print("Spawn point registered with ID: ", spawn_id)

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
