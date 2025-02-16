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
			sky.radiance_size = props.get("sky_radiance_size", Sky.RADIANCE_SIZE_256)
			sky.process_mode = props.get("sky_process_mode", Sky.PROCESS_MODE_AUTOMATIC)
			env.sky_custom_fov = props.get("sky_fov", 0.0)
			env.sky_rotation = props.get("sky_rotation", Vector3.ZERO)
	#endregion

	#region Ambient Light
	env.ambient_light_source = props.get("ambient_light_source", Environment.AMBIENT_SOURCE_COLOR)
	if env.ambient_light_source != Environment.AMBIENT_SOURCE_DISABLED:
		env.ambient_light_color = props.get("ambient_light_color", Color.WHITE)
		env.ambient_light_energy = props.get("ambient_light_energy", 1.0)
		env.ambient_light_sky_contribution = props.get("ambient_light_sky_contribution", 1.0)
	#endregion

	#region Reflected Light
	env.reflected_light_source = props.get("reflected_light_source", Environment.REFLECTION_SOURCE_DISABLED)
	#endregion

	#region Tonemap
	env.tonemap_mode = props.get("tonemap_mode", Environment.TONE_MAPPER_LINEAR)
	env.tonemap_exposure = props.get("tonemap_exposure", 1.0)
	env.tonemap_white = props.get("tonemap_white", 1.0)
	#endregion

	#region Screen Space Reflections (SSR)
	env.ssr_enabled = props.get("ssr_enabled", false)
	if env.ssr_enabled:
		env.ssr_max_steps = props.get("ssr_max_steps", 64)
		env.ssr_fade_in = props.get("ssr_fade_in", 0.15)
		env.ssr_fade_out = props.get("ssr_fade_out", 2.0)
		env.ssr_depth_tolerance = props.get("ssr_depth_tolerance", 0.2)
	#endregion

	#region Screen Space Ambient Occlusion (SSAO)
	env.ssao_enabled = props.get("ssao_enabled", false)
	if env.ssao_enabled:
		env.ssao_radius = props.get("ssao_radius", 1.0)
		env.ssao_intensity = props.get("ssao_intensity", 2.0)
		env.ssao_power = props.get("ssao_power", 1.5)
		env.ssao_detail = props.get("ssao_detail", 0.5)
		env.ssao_horizon = props.get("ssao_horizon", 0.06)
		env.ssao_sharpness = props.get("ssao_sharpness", 0.98)
		env.ssao_light_affect = props.get("ssao_light_affect", 0.0)
		env.ssao_ao_channel_affect = props.get("ssao_ao_channel_affect", 0.0)
	#endregion

	#region Screen Space Indirect Lighting (SSIL)
	env.ssil_enabled = props.get("ssil_enabled", false)
	if env.ssil_enabled:
		env.ssil_radius = props.get("ssil_radius", 5.0)
		env.ssil_intensity = props.get("ssil_intensity", 1.0)
		env.ssil_sharpness = props.get("ssil_sharpness", 0.98)
		env.ssil_normal_rejection = props.get("ssil_normal_rejection", 1.0)
	#endregion

	#region Signed Distance Field Global Illumination (SDFGI)
	env.sdfgi_enabled = props.get("sdfgi_enabled", false)
	if env.sdfgi_enabled:
		env.sdfgi_use_occlusion = props.get("sdfgi_use_occlusion", false)
		env.sdfgi_read_sky_light = props.get("sdfgi_read_sky_light", true)
		env.sdfgi_bounce_feedback = props.get("sdfgi_bounce_feedback", 0.5)
		env.sdfgi_cascades = props.get("sdfgi_cascades", 4)
		env.sdfgi_min_cell_size = props.get("sdfgi_min_cell_size", 0.2)
		env.sdfgi_cascade0_distance = props.get("sdfgi_cascade0_distance", 12.8)
		env.sdfgi_max_distance = props.get("sdfgi_max_distance", 204.8)
		env.sdfgi_y_scale = props.get("sdfgi_y_scale", Environment.SDFGI_Y_SCALE_75_PERCENT)
		env.sdfgi_energy = props.get("sdfgi_energy", 1.0)
		env.sdfgi_normal_bias = props.get("sdfgi_normal_bias", 1.1)
		env.sdfgi_probe_bias = props.get("sdfgi_probe_bias", 1.1)
	#endregion

	#region Volumetric Fog
	env.volumetric_fog_enabled = props.get("volumetric_fog_enabled", false)
	if env.volumetric_fog_enabled:
		env.volumetric_fog_density = props.get("volumetric_fog_density", 0.05)
		env.volumetric_fog_albedo = props.get("volumetric_fog_albedo", Color.WHITE)
		env.volumetric_fog_emission = props.get("volumetric_fog_emission", Color.BLACK)
		env.volumetric_fog_emission_energy = props.get("volumetric_fog_emission_energy", 1.0)
		env.volumetric_fog_gi_inject = props.get("volumetric_fog_gi_inject", 1.0)
		env.volumetric_fog_anisotropy = props.get("volumetric_fog_anisotropy", 0.2)
		env.volumetric_fog_length = props.get("volumetric_fog_length", 64.0)
		env.volumetric_fog_detail_spread = props.get("volumetric_fog_detail_spread", 2.0)
		env.volumetric_fog_ambient_inject = props.get("volumetric_fog_ambient_inject", 0.0)
		env.volumetric_fog_sky_affect = props.get("volumetric_fog_sky_affect", 1.0)
		env.volumetric_fog_temporal_reprojection_enabled = props.get("volumetric_fog_temporal_reprojection_enabled", true)
		env.volumetric_fog_temporal_reprojection_amount = props.get("volumetric_fog_temporal_reprojection_amount", 0.9)
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
		env.glow_hdr_threshold = props.get("glow_hdr_threshold", 1.0)
		env.glow_hdr_scale = props.get("glow_hdr_scale", 2.0)
		env.glow_hdr_luminance_cap = props.get("glow_hdr_luminance_cap", 12.0)
	#endregion

	#region Adjustments
	env.adjustment_enabled = props.get("adjustment_enabled", false)
	if env.adjustment_enabled:
		env.adjustment_brightness = props.get("adjustment_brightness", 1.0)
		env.adjustment_contrast = props.get("adjustment_contrast", 1.0)
		env.adjustment_saturation = props.get("adjustment_saturation", 1.0)

		var cc_path = props.get("adjustment_color_correction_path", "")
		if ResourceLoader.exists(cc_path):
			var cc = load(cc_path)
			if cc is Texture2D or cc is Texture3D:
				env.adjustment_color_correction = cc
	#endregion

	environment = env
