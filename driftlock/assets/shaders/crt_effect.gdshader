shader_type canvas_item;
render_mode unshaded;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float pixel_size : hint_range(1.0, 10.0) = 2.0;
uniform float color_bits : hint_range(1.0, 8.0) = 5.0;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.1;
uniform float scanlines_opacity : hint_range(0.0, 1.0) = 0.3;
uniform float scroll_speed : hint_range(0.0, 1.0, 0.1) = 0.5;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.3;
uniform float vignette_size : hint_range(0.0, 1.0) = 0.7;
uniform float chrom_aberration : hint_range(0.0, 5.0) = 1.0;
uniform float noise_strength : hint_range(0.0, 0.2) = 0.02;
uniform float time = 0.0;

float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

float dither(vec2 pos) {
    const int matrix[16] = int[16](
        0, 8, 2, 10,
        12, 4, 14, 6,
        3, 11, 1, 9,
        15, 7, 13, 5
    );
    
    int x = int(mod(pos.x, 4.0));
    int y = int(mod(pos.y, 4.0));
    int index = y * 4 + x;
    
    return float(matrix[index]) / 16.0;
}

void fragment() {
    vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
    
    vec2 pixelated_uv = floor(UV * screen_size / pixel_size) * pixel_size / screen_size;
    
    float aberration = chrom_aberration * 0.001;
    vec3 color;
    color.r = texture(SCREEN_TEXTURE, vec2(pixelated_uv.x + aberration, pixelated_uv.y)).r;
    color.g = texture(SCREEN_TEXTURE, pixelated_uv).g;
    color.b = texture(SCREEN_TEXTURE, vec2(pixelated_uv.x - aberration, pixelated_uv.y)).b;
    
    float color_levels = pow(2.0, color_bits);
    color = floor(color * color_levels) / (color_levels - 1.0);
    
    if (dither_strength > 0.0) {
        float dither_value = dither(FRAGCOORD.xy) * dither_strength;
        color += vec3(dither_value) - dither_strength * 0.5;
        color = clamp(color, 0.0, 1.0);
    }
    
    if (scanlines_opacity > 0.0) {
		float scanline = sin((UV.y + time * scroll_speed) * screen_size.y * 0.5);
        color = mix(color, color * (0.5 + 0.5 * scanline), scanlines_opacity);
    }
    
    if (vignette_strength > 0.0) {
        float vignette = distance(UV, vec2(0.5));
        vignette = smoothstep(vignette_size, 1.0, vignette);
        color = mix(color, color * (1.0 - vignette), vignette_strength);
    }
    
    if (noise_strength > 0.0) {
        float noise = rand(UV + vec2(time * 0.01, time * 0.01)) * 2.0 - 1.0;
        color += vec3(noise * noise_strength);
        color = clamp(color, 0.0, 1.0);
    }
    
    COLOR = vec4(color, 1.0);
}