shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;
render_mode unshaded;

uniform float flow_speed : hint_range(0.1, 5.0) = 1.0;
uniform float color_saturation : hint_range(0.0, 2.0) = 1.0;
uniform float color_brightness : hint_range(0.0, 2.0) = 1.2;
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.2;
uniform float rainbow_scale : hint_range(1.0, 10.0) = 2.0;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.6;
uniform float glow_strength : hint_range(0.0, 2.0) = 0.8;
uniform float transparency : hint_range(0.0, 1.0) = 0.7;
uniform float time;

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x) +
            (c - a)* u.y * (1.0 - u.x) +
            (d - b) * u.x * u.y;
}

void fragment() {
    vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    
    float hue = 0.0;
    
    float angle_xz = atan(world_pos.x, world_pos.z);
    hue += angle_xz / (2.0 * 3.14159) + 0.5;
    
    hue += world_pos.y * 0.2 * rainbow_scale;
    
    hue += time * flow_speed * 0.2;
    
    float noise_val = noise(vec2(world_pos.x * rainbow_scale * 0.5 + time * flow_speed * 0.3, 
                               world_pos.y * rainbow_scale * 0.5 + time * flow_speed * 0.2)) * 0.1;
    hue += noise_val;
    hue = fract(hue);
    vec3 color = hsv2rgb(vec3(hue, color_saturation, color_brightness));
    
    float pulse = sin(time * flow_speed * 2.0) * 0.5 + 0.5;
    color = mix(color, color * (1.0 + pulse_intensity), pulse * pulse_intensity);
    
    float fresnel = pow(1.0 - dot(NORMAL, VIEW), 3.0);
    color = mix(color, vec3(1.0), fresnel * rim_strength);
    
    ALBEDO = color;
    ALPHA = transparency;
    EMISSION = color * glow_strength;
    METALLIC = 0.3;
    SPECULAR = 0.7;
    ROUGHNESS = 0.2;
}