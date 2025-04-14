@tool
extends Area3D

@export var velocity: Vector3 = Vector3(0, 0, 0)

func _func_godot_apply_properties(props: Dictionary):
	if "velocity" in props:
		velocity = props["velocity"] as Vector3

func _init() -> void:
	connect("body_shape_entered", body_shape_entered)

func body_shape_entered(body_id, body: Node, body_shape_idx: int, self_shape_idx: int) -> void:
	if body is CharacterBody3D:
		if velocity.x != 0:
			body.velocity.x = velocity.x
		if velocity.y != 0:
			body.velocity.y = velocity.y
		if velocity.z != 0:
			body.velocity.z = velocity.z
