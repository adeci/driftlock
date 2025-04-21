@tool
extends Area3D

@export var show_debug_visuals: bool = false:
	set(value):
		show_debug_visuals = value
		if debug_visual:
			debug_visual.visible = value if not Engine.is_editor_hint() else false
			
@export var required_laps: int = 3:
	set(value):
		required_laps = max(1, value)  # Ensure at least 1 lap

var debug_visual: MeshInstance3D
var player_finish_cooldown: Dictionary = {}
var cooldown_time: float = 5.0

func _func_godot_apply_properties(props: Dictionary) -> void:
	if "show_debug_visuals" in props:
		show_debug_visuals = props["show_debug_visuals"] as bool
	if "required_laps" in props:
		required_laps = max(1, props["required_laps"] as int)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	print("Finish line ready at position: ", global_position)
	RaceManager.set_required_laps(required_laps)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		var player_id = body.get_multiplayer_authority()
		if player_finish_cooldown.has(player_id):
			var time_since_last = Time.get_ticks_msec() / 1000.0 - player_finish_cooldown[player_id]
			if time_since_last < cooldown_time:
				return
		player_finish_cooldown[player_id] = Time.get_ticks_msec() / 1000.0
		var race_completed = RaceManager.finish_race(player_id)
		if race_completed:
			# Visual/audio feedback could go here
			pass
