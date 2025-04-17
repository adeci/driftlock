shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_lambert, specular_schlick_ggx;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform vec4 water_color : source_color = vec4(0.0, 0.4, 0.6, 0.5);
uniform float wave_height : hint_range(0.0, 1.0) = 0.1;
uniform float wave_speed : hint_range(0.0, 10.0) = 1.0;
uniform bool foam_enabled = false;
uniform float time;

// Noise function to create ripples and surface variation
float noise(vec2 p) {
    vec2 ip = floor(p);
    vec2 fp = fract(p);
    fp = fp * fp * (3.0 - 2.0 * fp);
    
    float n00 = fract(sin(dot(ip, vec2(127.1, 311.7))) * 43758.5453);
    float n01 = fract(sin(dot(ip + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
    float n10 = fract(sin(dot(ip + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
    float n11 = fract(sin(dot(ip + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
    
    float nx0 = mix(n00, n10, fp.x);
    float nx1 = mix(n01, n11, fp.x);
    float nxy = mix(nx0, nx1, fp.y);
    
    return nxy * 2.0 - 1.0;
}

// Function to generate multiple layers of noise for more realistic water
float noisy_waves(vec2 wave_pos, float t) {
    // Layer 1: Large waves
    float wave1 = sin(wave_pos.x * 0.5 + t * 0.5) * cos(wave_pos.y * 0.3 + t * 0.3) * 0.5;
    
    // Layer 2: Medium waves at different angles
    float wave2 = sin(wave_pos.x * 1.2 + wave_pos.y * 0.7 + t * 0.8) * 0.25;
    
    // Layer 3: Small ripples
    vec2 noise_pos = wave_pos * 3.0 + t * 0.5;
    float ripples = noise(noise_pos) * 0.15;
    
    // Layer 4: Very small details
    vec2 detail_pos = wave_pos * 8.0 + t * 1.2;
    float details = noise(detail_pos) * 0.05;
    
    // Combine all layers
    return wave1 + wave2 + ripples + details;
}

varying vec3 vertex_world_position;
varying float vertex_height;

void vertex() {
    vertex_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    
    // Apply wave effect to the top surface only (where normal points up)
    if (NORMAL.y > 0.7) {
        vec2 wave_pos = vertex_world_position.xz * 0.2;
        
        // Use our complex noise function instead of simple sin/cos
        float wave = noisy_waves(wave_pos, time * wave_speed) * wave_height;
        
        VERTEX.y += wave;
        vertex_height = wave;
        
        // Recalculate normals for lighting based on the wave height differences
        vec2 e = vec2(0.01, 0.0);
        vec2 pos_x = wave_pos + e;
        vec2 pos_z = wave_pos + e.yx;
        
        float height_x = noisy_waves(pos_x, time * wave_speed) * wave_height;
        float height_z = noisy_waves(pos_z, time * wave_speed) * wave_height;
        
        vec3 tangent = normalize(vec3(e.x, height_x - wave, 0.0));
        vec3 bitangent = normalize(vec3(0.0, height_z - wave, e.x));
        
        NORMAL = normalize(cross(tangent, bitangent));
    }
}

void fragment() {
    // Base water color with depth-based opacity
    ALBEDO = water_color.rgb;
    
    // Calculate small ripples based on world position for surface detail
    vec2 ripple_pos = vertex_world_position.xz * 5.0 + time * 2.0;
    float ripple = noise(ripple_pos) * 0.05;
    
    // Add ripples to normal to create surface distortion
    NORMAL = normalize(NORMAL + vec3(ripple, 0.0, ripple));
    
    // Enhanced fresnel effect for edge highlighting with angle-dependent opacity
    float fresnel = pow(1.0 - dot(NORMAL, VIEW), 4.0);
    
    // More pronounced refraction effect
    vec2 screen_uv = SCREEN_UV + NORMAL.xz * (0.05 + ripple * 0.5);
    vec3 refraction = texture(SCREEN_TEXTURE, screen_uv).rgb;
    
    // Dynamic water surface
    float surface_animation = sin(time * 0.5 + vertex_world_position.x * 0.2 + vertex_world_position.z * 0.3) * 0.5 + 0.5;
    
    // Apply color variation based on ripples and waves
    vec3 ripple_color = mix(water_color.rgb, water_color.rgb * 1.3, ripple + surface_animation * 0.2);
    ALBEDO = ripple_color;
    
    // Combine effects with more pronounced transparency variation
    ALPHA = water_color.a + fresnel * 0.2 + ripple * 0.1;
    METALLIC = 0.2;
    ROUGHNESS = 0.15 + ripple * 0.1;
    SPECULAR = 0.8;
    
    // Add foam at the edges if enabled - more visible now
    if (foam_enabled) {
        // Edge detection
        float edge_detection = 1.0 - smoothstep(0.3, 0.7, abs(NORMAL.y));
        
        // Dynamic foam that follows the wave motion
        float foam_wave = sin(time * 1.2 + vertex_world_position.x * 0.4 + vertex_world_position.z * 0.4);
        float foam_noise = noise(vertex_world_position.xz * 0.5 + time * 0.2) * 0.5 + 0.5;
        
        // Combine for realistic foam effect
        float foam = edge_detection * (foam_noise + foam_wave * 0.2);
        foam = smoothstep(0.4, 0.8, foam);
        
        // Add foam to the color and reduce transparency where foam exists
        ALBEDO = mix(ALBEDO, vec3(1.0), foam * 0.7);
        ALPHA = mix(ALPHA, 1.0, foam * 0.8);
    }
    
    // Add slight depth-based color variation
    float depth_factor = clamp(length(vertex_world_position - CAMERA_POSITION_WORLD) * 0.1, 0.0, 1.0);
    ALBEDO = mix(ALBEDO, ALBEDO * 0.7, depth_factor * 0.3);
    
    // Enhanced underwater glow effect
    EMISSION = water_color.rgb * (0.1 + ripple * 0.05);
}