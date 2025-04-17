@tool
extends Node3D

@export var checkpoint_id: int = 1
@export var show_debug_visual: bool = true:
	set(value):
		show_debug_visual = value
		if debug_visual:
			debug_visual.visible = value if not Engine.is_editor_hint() else true

var debug_visual: MeshInstance3D

func _func_godot_apply_properties(props: Dictionary) -> void:
	if "checkpoint_id" in props:
		checkpoint_id = props["checkpoint_id"] as int
	if "show_debug_visual" in props:
		show_debug_visual = props["show_debug_visual"] as bool

func _ready() -> void:
	if Engine.is_editor_hint():
		create_debug_visual()
	else:
		create_debug_visual()
		# Register this respawn point with RaceManager
		RaceManager.register_respawn_point(checkpoint_id, global_position, global_rotation.y)
		
	print("Respawn point registered for checkpoint ID: ", checkpoint_id)

func create_debug_visual() -> void:
	if debug_visual:
		debug_visual.queue_free()
	
	debug_visual = MeshInstance3D.new()
	
	# Create a simple arrow pointing upward
	var arrow_mesh = CylinderMesh.new()
	arrow_mesh.top_radius = 0.0
	arrow_mesh.bottom_radius = 0.3
	arrow_mesh.height = 1.0
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.0, 0.8, 1.0)  # Cyan/blue
	material.emission_enabled = true
	material.emission = Color(0.0, 0.8, 1.0)
	material.emission_energy_multiplier = 2.0
	arrow_mesh.material = material
	
	debug_visual.mesh = arrow_mesh
	
	add_child(debug_visual)
	debug_visual.visible = show_debug_visual

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		if debug_visual:
			debug_visual.visible = true
