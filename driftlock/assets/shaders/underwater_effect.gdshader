shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float water_speed : hint_range(0.0, 2.0) = 0.5;
uniform float distortion_amplitude : hint_range(0.0, 0.1) = 0.02;
uniform float water_frequency : hint_range(1.0, 30.0) = 10.0;
uniform float water_depth : hint_range(0.0, 1.0) = 0.3;
uniform vec4 water_tint : source_color = vec4(0.0, 0.4, 0.6, 0.2);
uniform float time = 0.0;

void fragment() {
    vec2 wave_uv = SCREEN_UV;
    
    float wave1 = sin(wave_uv.x * water_frequency + time * water_speed) * 
                 cos(wave_uv.y * (water_frequency * 0.8) + time * water_speed * 0.7);
                 
    float wave2 = sin(wave_uv.y * (water_frequency * 1.2) + time * water_speed * 0.8) * 
                 cos(wave_uv.x * (water_frequency * 0.6) - time * water_speed * 0.9);
                 
    float wave3 = sin((wave_uv.x + wave_uv.y) * (water_frequency * 0.5) + time * water_speed * 1.1);
    
    float final_wave = (wave1 * 0.5 + wave2 * 0.3 + wave3 * 0.2) * distortion_amplitude;
    
    vec2 distorted_uv = SCREEN_UV;
    distorted_uv.x += final_wave;
    distorted_uv.y += final_wave * 0.8;
    
    vec4 screen_color = texture(SCREEN_TEXTURE, distorted_uv);
    
    vec4 tinted_color = mix(screen_color, water_tint, water_tint.a);
    
    float caustics = sin(wave_uv.x * (water_frequency * 2.0) + time * water_speed * 1.5) * 
                    sin(wave_uv.y * (water_frequency * 2.0) + time * water_speed) * 0.5 + 0.5;
    caustics *= 0.05;
    
    float darkness = 1.0 - water_depth;
    
    COLOR = tinted_color;
    COLOR.rgb += vec3(caustics);
    COLOR.rgb *= darkness;
}