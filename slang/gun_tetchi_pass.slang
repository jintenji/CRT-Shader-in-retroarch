#version 450

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
} params;

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main() {
    // Safety fallback to prevent divide-by-zero crashes during resolution switches
    vec2 res = (params.SourceSize.y > 50.0) ? params.SourceSize.xy : vec2(256.0, 224.0);

    // ----------------------------------------------------
    // 1. Omni-directional Sharp Bilinear Filtering
    // ----------------------------------------------------
    
    vec2 coord = vTexCoord * res - 0.5;
    vec2 index = floor(coord);
    vec2 weight = fract(coord);

    weight = clamp((weight - 0.5) * 3.0 + 0.5, 0.0, 1.0);

    vec2 uv00 = (index + vec2(0.5, 0.5)) / res;
    vec2 uv10 = (index + vec2(1.5, 0.5)) / res;
    vec2 uv01 = (index + vec2(0.5, 1.5)) / res;
    vec2 uv11 = (index + vec2(1.5, 1.5)) / res;

    vec4 c00 = texture(Source, uv00);
    vec4 c10 = texture(Source, uv10);
    vec4 c01 = texture(Source, uv01);
    vec4 c11 = texture(Source, uv11);

    vec4 color_top = mix(c00, c10, weight.x);
    vec4 color_bot = mix(c01, c11, weight.x);
    
    vec4 base_color = mix(color_top, color_bot, weight.y);

    float luminance = dot(base_color.rgb, vec3(0.299, 0.587, 0.114));

    // ----------------------------------------------------
    // 2. Fully Dynamic Sine Wave Scanlines (Resolution & Alignment Auto-Detect)
    // ----------------------------------------------------

    // Calculate vertical scaling ratio and integer alignment
    float scale_y = params.OutputSize.y / res.y;
    float alignment = abs(fract(scale_y) - 0.5) * 2.0;

    // Resolution Factor: Maps scale_y from 2.0 (handhelds) to 6.0+ (high-res TVs) 
    // to a 0.0 ~ 1.0 range. This tells us "how high is the output resolution?".
    float res_factor = clamp((scale_y - 2.0) / 4.0, 0.0, 1.0);

    // Auto-adjust sharpness limits based on device resolution to prevent "Screen Door" effect on handhelds.
    // Low res limits: 0.5 ~ 1.0 | High res limits: 1.5 ~ 3.0
    float sharp_min = mix(0.5, 1.5, res_factor);
    float sharp_max = mix(1.0, 3.0, res_factor);
    
    // Auto-adjust brightness boost limits based on device resolution.
    // Low res needs more gap brightness: 0.25 ~ 0.45 | High res needs less: 0.05 ~ 0.15
    float boost_min = mix(0.25, 0.05, res_factor);
    float boost_max = mix(0.45, 0.15, res_factor);

    // Apply the math
    float phase = vTexCoord.y * res.y * 3.14159265;
    float scan_wave = sin(phase);
    float scanline = scan_wave * scan_wave;
    
    // Calculate final sharpness and boost using the alignment and the dynamic limits
    float dynamic_sharpness = mix(sharp_min, sharp_max, alignment);
    float beam_profile = mix(pow(scanline, dynamic_sharpness), scanline, luminance);
    
    // Poor alignment gets max boost to hide Moire, perfect alignment gets min boost
    float dynamic_boost = mix(boost_max, boost_min, alignment);
    beam_profile = clamp(beam_profile + dynamic_boost, 0.0, 1.0);
    
    FragColor = vec4(base_color.rgb * beam_profile, 1.0);
}