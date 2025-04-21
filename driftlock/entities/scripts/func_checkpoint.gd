@tool
extends Area3D

@export var checkpoint_id: int = 1
@export var required: bool = true
@export var show_debug_visuals: bool = false:
	set(value):
		show_debug_visuals = value
		if debug_visual:
			debug_visual.visible = value if not Engine.is_editor_hint() else false

var debug_visual: MeshInstance3D

func _func_godot_apply_properties(props: Dictionary) -> void:
	if "checkpoint_id" in props:
		checkpoint_id = props["checkpoint_id"] as int
	if "required" in props:
		required = props["required"] as bool
	if "show_debug_visuals" in props:
		show_debug_visuals = props["show_debug_visuals"] as bool

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	RaceManager.register_checkpoint(self, checkpoint_id, required)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		var player_id = body.get_multiplayer_authority()
		RaceManager.activate_checkpoint(checkpoint_id, player_id, body.global_position)
