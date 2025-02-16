@tool
extends OmniLight3D

func _func_godot_apply_properties(props: Dictionary):
	if "light_color" in props:
		light_color = Color(props["light_color"])
	if "intensity" in props:
		light_energy = float(props["intensity"])
	if "range" in props:
		omni_range = float(props["range"])

func _func_godot_build_complete():
	print("Torch light entity built successfully!")
