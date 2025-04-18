@tool
extends Area3D

@export var kill_delay: float = 0.0  # Delay before respawning (seconds)
@export var show_debug_visual: bool = true:
	set(value):
		show_debug_visual = value
		if debug_visual:
			debug_visual.visible = value if not Engine.is_editor_hint() else true

var debug_visual: MeshInstance3D

func _func_godot_apply_properties(props: Dictionary) -> void:
	if "kill_delay" in props:
		kill_delay = props["kill_delay"] as float
	if "show_debug_visual" in props:
		show_debug_visual = props["show_debug_visual"] as bool

func _ready() -> void:
	if Engine.is_editor_hint():
		create_debug_visual()
		return
		
	# Connect signals
	body_entered.connect(_on_body_entered)
	
	create_debug_visual()
	
	print("Killzone ready at position: ", global_position)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		var player_id = body.get_multiplayer_authority()
		
		# Kill the player and trigger respawn
		if kill_delay > 0:
			await get_tree().create_timer(kill_delay).timeout
		
		# Call RaceManager to handle the respawn
		RaceManager.start_respawn(player_id)
		
		print("Player " + str(player_id) + " entered killzone and will respawn.")

func create_debug_visual() -> void:
	if debug_visual:
		debug_visual.queue_free()
	
	debug_visual = MeshInstance3D.new()
	
	# Create a simple visual representation
	var mesh = BoxMesh.new()
	mesh.size = Vector3(1.0, 1.0, 1.0)
	
	# Create material for the killzone
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.0, 0.0, 0.3)  # Red, semi-transparent
	material.emission_enabled = true
	material.emission = Color(1.0, 0.0, 0.0, 1.0)
	material.emission_energy_multiplier = 1.5
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	
	debug_visual.mesh = mesh
	
	add_child(debug_visual)
	debug_visual.visible = show_debug_visual

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		if debug_visual:
			debug_visual.visible = true
