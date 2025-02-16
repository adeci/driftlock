@tool
extends WorldEnvironment

@export var mapname: String = ""
@export var music: String = ""

func _func_godot_apply_properties(props: Dictionary) -> void:
	mapname = props.get("mapname", "")
	music = props.get("music", "")

	var env = Environment.new()

	#region Background
	env.background_mode = props.get("bg_mode", Environment.BG_COLOR)
	env.background_color = props.get("bg_color", Color.BLACK)
	env.background_energy_multiplier = props.get("bg_energy_multiplier", 1.0)

	if env.background_mode == Environment.BG_CANVAS:
		env.background_canvas_max_layer = props.get("bg_canvas_max_layer", 0)
	elif env.background_mode == Environment.BG_CAMERA_FEED:
		env.background_camera_feed_id = props.get("bg_camera_feed_id", 1)
	#endregion

	#region Sky
	if env.background_mode == Environment.BG_SKY:
		var sky = Sky.new()
		if ResourceLoader.exists(props.get("sky_material", "")):
			var sky_mat = load(props["sky_material"])
			if sky_mat is ShaderMaterial or sky_mat is PanoramaSkyMaterial or sky_mat is ProceduralSkyMaterial or sky_mat is PhysicalSkyMaterial:
				sky.sky_material = sky_mat
			env.sky_custom_fov = props.get("sky_fov", 0.0)
			env.sky_rotation = props.get("sky_rotation", Vector3.ZERO)
	#endregion

	#region Ambient Light
	env.ambient_light_source = props.get("ambient_light_source", Environment.AMBIENT_SOURCE_COLOR)
	if env.ambient_light_source != Environment.AMBIENT_SOURCE_DISABLED:
		env.ambient_light_color = props.get("ambient_light_color", Color.WHITE)
		env.ambient_light_energy = props.get("ambient_light_energy", 1.0)
	#endregion

	#region Fog
	env.fog_enabled = props.get("fog_enabled", false)
	if env.fog_enabled:
		env.fog_mode = props.get("fog_mode", Environment.FOG_MODE_EXPONENTIAL)
		env.fog_light_color = props.get("fog_light_color", Color("848d9b"))
		env.fog_light_energy = props.get("fog_light_energy", 1.0)
		env.fog_density = props.get("fog_density", 0.01)
		env.fog_sky_affect = props.get("fog_sky_affect", 1.0)
		env.fog_height = props.get("fog_height", 0.0)
		env.fog_height_density = props.get("fog_height_density", 0.0)
	#endregion

	#region Glow
	env.glow_enabled = props.get("glow_enabled", false)
	if env.glow_enabled:
		env.glow_intensity = props.get("glow_intensity", 0.8)
		env.glow_strength = props.get("glow_strength", 1.0)
		env.glow_bloom = props.get("glow_bloom", 0.0)
		env.glow_blend_mode = props.get("glow_blend_mode", Environment.GLOW_BLEND_MODE_SOFTLIGHT)
	#endregion

	#region Adjustments
	env.adjustment_enabled = props.get("adjustment_enabled", false)
	if env.adjustment_enabled:
		env.adjustment_brightness = props.get("adjustment_brightness", 1.0)
		env.adjustment_contrast = props.get("adjustment_contrast", 1.0)
		env.adjustment_saturation = props.get("adjustment_saturation", 1.0)
	#endregion

	environment = env
