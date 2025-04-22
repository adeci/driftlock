@tool
extends Area3D

@export var velocity: Vector3 = Vector3(0, 0, 0)

func _func_godot_apply_properties(props: Dictionary):
	if "velocity" in props:
		velocity = props["velocity"] as Vector3

func _init() -> void:
	connect("body_shape_entered", body_shape_entered)

func body_shape_entered(_body_id, body: Node, _body_shape_idx: int, _self_shape_idx: int) -> void:
	if body is CharacterBody3D:
		# Apply velocity changes
		if velocity.x != 0:
			body.velocity.x = velocity.x
		if velocity.y != 0:
			body.velocity.y = velocity.y
		if velocity.z != 0:
			body.velocity.z = velocity.z
	SoundManager.play_sound(SoundManager.SoundCatalog.SPEED_BOOST, true, body.global_position)
