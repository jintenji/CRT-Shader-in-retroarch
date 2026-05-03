#version 450

#pragma parameter MASK_SCALE "Phosphor Mask Scale" 1.0 1.0 4.0 1.0

layout(push_constant) uniform Push { 
    vec4 SourceSize; vec4 OriginalSize; vec4 OutputSize; uint FrameCount; 
    float MASK_SCALE;
} params;
layout(std140, set = 0, binding = 0) uniform UBO { mat4 MVP; } global;

#pragma stage vertex
layout(location = 0) in vec4 Position; layout(location = 1) in vec2 TexCoord; layout(location = 0) out vec2 vTexCoord;
void main() { gl_Position = global.MVP * Position; vTexCoord = TexCoord; }

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord; layout(location = 0) out vec4 FragColor; layout(set = 0, binding = 2) uniform sampler2D Source;

void main() {
    vec4 center_color = texture(Source, vTexCoord);
    float luminance = dot(center_color.rgb, vec3(0.299, 0.587, 0.114));

    float bloom_strength = 3.0; 
    float radius = (luminance * bloom_strength) / params.OutputSize.x; 
    
    vec3 bloom_color = vec3(0.0);
    bloom_color += texture(Source, vTexCoord + vec2(-radius * 2.0, 0.0)).rgb * 0.06;
    bloom_color += texture(Source, vTexCoord + vec2(-radius, 0.0)).rgb * 0.24;
    bloom_color += center_color.rgb * 0.40;
    bloom_color += texture(Source, vTexCoord + vec2(radius, 0.0)).rgb * 0.24;
    bloom_color += texture(Source, vTexCoord + vec2(radius * 2.0, 0.0)).rgb * 0.06;

    float brightness_boost = 1.35; 
    vec3 white_balance = vec3(0.95, 1.15, 0.95); 
    bloom_color *= (brightness_boost * white_balance);

    // Slot Mask Generation 
    float scale = params.MASK_SCALE;
    vec2 pos = (vTexCoord * params.OutputSize.xy) / scale;
    float triad_width = 3.0;
    float slot_height = 4.0;

    float column = floor(pos.x / triad_width);
    float stagger = mod(column, 2.0) * 0.5;
    float slot_y = fract((pos.y / slot_height) + stagger);

    float gap_darkness = 0.35;
    float vertical_mask = (slot_y < 0.15 || slot_y > 0.85) ? gap_darkness : 1.0;

    float mask_pos = fract(pos.x / triad_width);
    vec3 mask = vec3(0.0);
    float mask_base = 0.45; 
    
    if (mask_pos < 0.333) mask = vec3(1.0, mask_base, mask_base);
    else if (mask_pos < 0.666) mask = vec3(mask_base, 1.0, mask_base);
    else mask = vec3(mask_base, mask_base, 1.0);

    vec3 final_color = bloom_color * mask * vertical_mask;

    float mask_brightness = 1.15; 
    final_color *= mask_brightness;

    float contrast = 1.45;
    float midpoint = 0.5;    
    float real_gamma = 2.2;  

    final_color = (final_color - midpoint) * contrast + midpoint;
    final_color = pow(max(final_color, 0.0), vec3(1.0 / real_gamma));

    FragColor = vec4(final_color, 1.0);
}