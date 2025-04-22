shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec4 water_color : source_color = vec4(0.0, 0.4, 0.6, 0.5);
uniform float wave_height : hint_range(0.0, 1.0) = 0.1;
uniform float wave_speed : hint_range(0.0, 10.0) = 1.0;
uniform float time;

void vertex() {
    vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    if (NORMAL.y > 0.7) {
        float wave1 = sin(world_pos.x * 2.0 + time * wave_speed) * cos(world_pos.z * 1.5 + time * wave_speed * 0.8) * wave_height;
        float wave2 = sin(world_pos.z * 1.7 + time * wave_speed * 0.9) * cos(world_pos.x * 1.3 + time * wave_speed * 0.7) * wave_height * 0.6;

        VERTEX.y += wave1 + wave2;

        vec3 tangent = normalize(vec3(0.0, wave_height * cos(world_pos.x + time * wave_speed), 0.2));
        vec3 bitangent = normalize(vec3(0.2, wave_height * cos(world_pos.z + time * wave_speed), 0.0));
        NORMAL = normalize(cross(tangent, bitangent));
    }
}

void fragment() {
    ALBEDO = water_color.rgb;
    float fresnel = pow(1.0 - dot(NORMAL, VIEW), 3.0);
    ALPHA = water_color.a + fresnel * 0.1;

    METALLIC = 0.1;
    ROUGHNESS = 0.2;
    SPECULAR = 0.5;

    EMISSION = water_color.rgb * 0.05;
}