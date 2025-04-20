@tool
extends Area3D

# Delay before respawning (seconds)
@export var kill_delay: float = 0.0
@export var show_debug_visual: bool = false:
	set(value):
		show_debug_visual = value
		if debug_visual:
			debug_visual.visible = value if not Engine.is_editor_hint() else false

var debug_visual: MeshInstance3D

func _func_godot_apply_properties(props: Dictionary) -> void:
	if "kill_delay" in props:
		kill_delay = props["kill_delay"] as float
	if "show_debug_visual" in props:
		show_debug_visual = props["show_debug_visual"] as bool

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	print("Killzone ready at position: ", global_position)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		var player_id = body.get_multiplayer_authority()
		if kill_delay > 0:
			await get_tree().create_timer(kill_delay).timeout
		RaceManager.start_respawn(player_id)
		print("Player " + str(player_id) + " entered killzone and will respawn.")
