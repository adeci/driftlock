extends Node

func use_targets(activator: Node, target: String) -> void:
	# Targetnames are really Godot Groups, so we can have multiple entities 
	# share a common "targetname" in Trenchbroom.
	var target_list: Array[Node] = get_tree().get_nodes_in_group(target)
	for targ in target_list:
		var f: String
		# Be careful when specifying a function since we can't pass arguments 
		# to it (without hackarounds of course)
		if 'targetfunc' in activator:
			f = activator.targetfunc
		if f.is_empty():
			f = "use"
		if targ.has_method(f):
			targ.call(f)

func set_targetname(node: Node, targetname: String) -> void:
	if node != null and not targetname.is_empty():
		node.add_to_group(targetname)
