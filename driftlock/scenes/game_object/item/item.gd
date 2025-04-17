@tool
extends Area3D

@export var respawn_time: float = 10

var timer: Timer = Timer.new()

func _func_godot_apply_properties(props: Dictionary):
	if "respawn_time" in props:
		respawn_time = props["respawn_time"] as float

func _init() -> void:
	connect("body_shape_entered", body_shape_entered)

func _ready() -> void:
	add_child(timer)
	timer.one_shot = true
	timer.autostart = false
	timer.wait_time = respawn_time
	timer.timeout.connect(_on_timer_timeout)

func body_shape_entered(_body_id, body: Node, _body_shape_idx: int, _self_shape_idx: int) -> void:
	if timer.is_stopped() and body is CharacterBody3D and body.has_method("set_item"):
		body.set_item(GameManager.generateItem())
		visible = false
		timer.start()

func _on_timer_timeout() -> void:
	visible = true
