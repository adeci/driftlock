@tool
extends Area3D

@export var show_debug_visuals: bool = false:
	set(value):
		show_debug_visuals = value
		if debug_visual:
			debug_visual.visible = value if not Engine.is_editor_hint() else false

var debug_visual: MeshInstance3D
var player_finish_cooldown: Dictionary = {}
var cooldown_time: float = 5.0  # Seconds between finish attempts

func _func_godot_apply_properties(props: Dictionary) -> void:
	if "show_debug_visuals" in props:
		show_debug_visuals = props["show_debug_visuals"] as bool

func _ready() -> void:
	if Engine.is_editor_hint():
		if not debug_visual:
			create_debug_visual()
		return
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	
	# Create visual representation
	create_debug_visual()
	
	print("Finish line ready at position: ", global_position)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		var player_id = body.get_multiplayer_authority()
		
		# Check for cooldown
		if player_finish_cooldown.has(player_id):
			var time_since_last = Time.get_ticks_msec() / 1000.0 - player_finish_cooldown[player_id]
			if time_since_last < cooldown_time:
				return
		
		# Update cooldown
		player_finish_cooldown[player_id] = Time.get_ticks_msec() / 1000.0
		
		# Notify RaceManager
		var race_completed = RaceManager.finish_race(player_id)
		
		if race_completed:
			# Visual/audio feedback could go here
			pass

func create_debug_visual() -> void:
	if debug_visual:
		debug_visual.queue_free()
	
	# Create a simple visual representation
	debug_visual = MeshInstance3D.new()
	
	# Create a cylinder mesh oriented horizontally (like a gate)
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.5
	cylinder.bottom_radius = 0.5
	cylinder.height = 5.0
	
	# Create material for the finish line
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.0, 0.0, 0.5)  # Red, semi-transparent
	material.emission_enabled = true
	material.emission = Color(1.0, 0.0, 0.0, 1.0)
	material.emission_energy_multiplier = 2.0
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
