@tool
extends Area3D

@export var checkpoint_id: int = 1
@export var required: bool = true
@export var show_debug_visuals: bool = true:
	set(value):
		show_debug_visuals = value
		if debug_visual:
			debug_visual.visible = value if not Engine.is_editor_hint() else true

var debug_visual: MeshInstance3D
var active_players: Array[int] = []

func _func_godot_apply_properties(props: Dictionary) -> void:
	if "checkpoint_id" in props:
		checkpoint_id = props["checkpoint_id"] as int
	if "required" in props:
		required = props["required"] as bool
	if "show_debug_visuals" in props:
		show_debug_visuals = props["show_debug_visuals"] as bool

func _ready() -> void:
	if Engine.is_editor_hint():
		if not debug_visual:
			create_debug_visual()
		return
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	
	# Register with RaceManager
	RaceManager.register_checkpoint(self, checkpoint_id, required)
	
	# Create visual representation
	create_debug_visual()

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		var player_id = body.get_multiplayer_authority()
		
		# Skip if already activated by this player
		if active_players.has(player_id):
			return
		
		active_players.append(player_id)
		
		# Notify RaceManager
		RaceManager.activate_checkpoint(checkpoint_id, player_id, body.global_position)

func create_debug_visual() -> void:
	if debug_visual:
		debug_visual.queue_free()
	
	# Create a simple visual representation
	debug_visual = MeshInstance3D.new()
	
	# Create a cylinder mesh oriented horizontally (like a gate)
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.5
	cylinder.bottom_radius = 0.5
	cylinder.height = 4.0
	
	# Create material for the checkpoint
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.0, 1.0, 0.0, 0.5)  # Green, semi-transparent
	material.emission_enabled = true
	material.emission = Color(0.0, 1.0, 0.0, 1.0)
	material.emission_energy_multiplier = 1.5
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cylinder.material = material
	
	debug_visual.mesh = cylinder
	debug_visual.rotation_degrees = Vector3(0, 0, 90)  # Make it vertical
	
	add_child(debug_visual)
	debug_visual.visible = show_debug_visuals

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		if debug_visual:
			debug_visual.visible = true
