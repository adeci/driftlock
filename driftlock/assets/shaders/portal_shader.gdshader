shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_lambert, specular_schlick_ggx;
render_mode unshaded;

uniform vec4 portal_color : source_color = vec4(0.5, 0.0, 0.8, 0.7);
uniform vec4 portal_edge_color : source_color = vec4(0.9, 0.2, 1.0, 0.9);
uniform float portal_speed : hint_range(0.1, 5.0) = 1.0;
uniform float portal_distortion : hint_range(0.0, 2.0) = 0.5;
uniform float portal_scale : hint_range(0.1, 10.0) = 3.0;
uniform float edge_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float time;

// Simplex noise functions from https://gist.github.com/patriciogonzalezvivo/670c22f3966e662d2f83
vec4 permute(vec4 x) { return mod(((x*34.0)+1.0)*x, 289.0); }
vec4 taylorInvSqrt(vec4 r) { return 1.79284291400159 - 0.85373472095314 * r; }

float snoise(vec3 v) { 
    const vec2 C = vec2(1.0/6.0, 1.0/3.0);
    const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);
    
    // First corner
    vec3 i  = floor(v + dot(v, C.yyy));
    vec3 x0 = v - i + dot(i, C.xxx);
    
    // Other corners
    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = 1.0 - g;
    vec3 i1 = min(g.xyz, l.zxy);
    vec3 i2 = max(g.xyz, l.zxy);
    
    vec3 x1 = x0 - i1 + 1.0 * C.xxx;
    vec3 x2 = x0 - i2 + 2.0 * C.xxx;
    vec3 x3 = x0 - 1.0 + 3.0 * C.xxx;
    
    // Permutations
    i = mod(i, 289.0); 
    vec4 p = permute(permute(permute(
             i.z + vec4(0.0, i1.z, i2.z, 1.0))
           + i.y + vec4(0.0, i1.y, i2.y, 1.0)) 
           + i.x + vec4(0.0, i1.x, i2.x, 1.0));
           
    // Gradients
    float n_ = 1.0/7.0; // N=7
    vec3 ns = n_ * D.wyz - D.xzx;
    
    vec4 j = p - 49.0 * floor(p * ns.z *ns.z);
    
    vec4 x_ = floor(j * ns.z);
    vec4 y_ = floor(j - 7.0 * x_);
    
    vec4 x = x_ *ns.x + ns.yyyy;
    vec4 y = y_ *ns.x + ns.yyyy;
    vec4 h = 1.0 - abs(x) - abs(y);
    
    vec4 b0 = vec4(x.xy, y.xy);
    vec4 b1 = vec4(x.zw, y.zw);
    
    vec4 s0 = floor(b0)*2.0 + 1.0;
    vec4 s1 = floor(b1)*2.0 + 1.0;
    vec4 sh = -step(h, vec4(0.0));
    
    vec4 a0 = b0.xzyw + s0.xzyw*sh.xxyy;
    vec4 a1 = b1.xzyw + s1.xzyw*sh.zzww;
    
    vec3 p0 = vec3(a0.xy, h.x);
    vec3 p1 = vec3(a0.zw, h.y);
    vec3 p2 = vec3(a1.xy, h.z);
    vec3 p3 = vec3(a1.zw, h.w);
    
    // Normalise gradients
    vec4 norm = taylorInvSqrt(vec4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;
    
    // Mix final noise value
    vec4 m = max(0.6 - vec4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
    m = m * m;
    return 42.0 * dot(m*m, vec4(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
}

void vertex() {
    // Add slight vertex displacement for the portal effect
    if (abs(NORMAL.y) < 0.1) { // Only affect the sides, not top/bottom
        float noise = snoise(vec3(VERTEX.xz * portal_scale * 0.1, time * portal_speed * 0.2));
        VERTEX += NORMAL * noise * 0.02;
    }
}

void fragment() {
    // Calculate UV coordinates for portal effects
    vec2 uv = UV;
    
    // Create swirling portal effect
    float time_factor = time * portal_speed;
    vec2 center = vec2(0.5, 0.5);
    vec2 centered_uv = uv - center;
    
    // Rotate UVs over time
    float angle = time_factor * 0.3;
    vec2 rotated_uv = vec2(
        centered_uv.x * cos(angle) - centered_uv.y * sin(angle),
        centered_uv.x * sin(angle) + centered_uv.y * cos(angle)
    );
    
    // Calculate distance from center for edge glow
    float dist = length(centered_uv);
    
    // Create distortion effect
    float noise1 = snoise(vec3(rotated_uv * portal_scale, time_factor * 0.5)) * 0.5 + 0.5;
    float noise2 = snoise(vec3(rotated_uv * portal_scale * 0.7, time_factor * 0.8 + 100.0)) * 0.5 + 0.5;
    
    // Combine noises for more interesting patterns
    float combined_noise = mix(noise1, noise2, 0.5 + sin(time_factor) * 0.5);
    
    // Apply edge glow
    float edge_glow = smoothstep(0.5, 0.4, dist);
    
    // Mix portal colors based on noise
    vec4 final_color = mix(portal_color, portal_edge_color, combined_noise);
    
    // Add edge effect
    final_color = mix(final_color, portal_edge_color, edge_glow * edge_intensity);
    
    // Add subtle pulsing effect
    final_color.a *= 0.7 + sin(time_factor * 1.5) * 0.1;
    
    // Apply distortion to emission
    float emission_strength = 1.0 + combined_noise * portal_distortion;
    
    // Set output
    ALBEDO = final_color.rgb;
    ALPHA = final_color.a;
    EMISSION = final_color.rgb * emission_strength;
    METALLIC = 0.7;
    SPECULAR = 1.0;
    ROUGHNESS = 0.2;
}