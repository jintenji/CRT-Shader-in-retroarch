// VERTEX SHADER
#if defined(VERTEX)

attribute vec4 VertexCoord;
attribute vec2 TexCoord;
uniform mat4 MVPMatrix;
varying vec2 vTexCoord;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord;
}

// FRAGMENT SHADER
#elif defined(FRAGMENT)

#ifdef GL_ES
precision mediump float;
#endif

varying vec2 vTexCoord;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform vec2 OutputSize;

void main() {
    // 0. Resolution safety check (prevent division by zero)
    vec2 res = (TextureSize.y > 50.0) ? TextureSize.xy : vec2(256.0, 224.0);

    // ----------------------------------------------------
    // 1. Omni-directional Sharp Bilinear Filtering
    // ----------------------------------------------------
    vec2 coord = vTexCoord * res - 0.5;
    vec2 index = floor(coord);
    vec2 weight = fract(coord);

    // Core operation to keep pixel centers sharp while smoothing edges
    weight = clamp((weight - 0.5) * 3.0 + 0.5, 0.0, 1.0);

    vec2 uv00 = (index + vec2(0.5, 0.5)) / res;
    vec2 uv10 = (index + vec2(1.5, 0.5)) / res;
    vec2 uv01 = (index + vec2(0.5, 1.5)) / res;
    vec2 uv11 = (index + vec2(1.5, 1.5)) / res;

    // [Modified: Standard Linear Workflow] Decode sRGB to Linear space for accurate interpolation
    vec4 c00 = texture2D(Texture, uv00); c00.rgb = pow(c00.rgb, vec3(2.2));
    vec4 c10 = texture2D(Texture, uv10); c10.rgb = pow(c10.rgb, vec3(2.2));
    vec4 c01 = texture2D(Texture, uv01); c01.rgb = pow(c01.rgb, vec3(2.2));
    vec4 c11 = texture2D(Texture, uv11); c11.rgb = pow(c11.rgb, vec3(2.2));

    // Mix in linear space to maintain physical brightness accuracy
    vec4 color_top = mix(c00, c10, weight.x);
    vec4 color_bot = mix(c01, c11, weight.x);
    vec4 base_color = mix(color_top, color_bot, weight.y);

    // [Modified] Physically accurate linear luminance weights
    float luminance = dot(base_color.rgb, vec3(0.2126, 0.7152, 0.0722));

    // ----------------------------------------------------
    // 2. Fully Dynamic Sine Wave Scanlines
    // ----------------------------------------------------
    float scale_y = OutputSize.y / res.y;
    float alignment = abs(fract(scale_y) - 0.5) * 2.0;
    float res_factor = clamp((scale_y - 2.0) / 4.0, 0.0, 1.0);

    float sharp_min = mix(0.5, 1.5, res_factor);
    float sharp_max = mix(1.0, 3.0, res_factor);
    
    float boost_min = mix(0.25, 0.05, res_factor);
    float boost_max = mix(0.45, 0.15, res_factor);

    // Multiply by exact Pi to prevent scanline phase shifting
    float phase = vTexCoord.y * res.y * 3.14159265;
    float scan_wave = sin(phase);
    float scanline = scan_wave * scan_wave;
    
    float dynamic_sharpness = mix(sharp_min, sharp_max, alignment);
    float beam_profile = mix(pow(scanline, dynamic_sharpness), scanline, luminance);
    
    float dynamic_boost = mix(boost_max, boost_min, alignment);
    beam_profile = clamp(beam_profile + dynamic_boost, 0.0, 1.0);
    
    vec3 out_color = base_color.rgb * beam_profile;

    // [Modified: Standard Linear Workflow] Re-compress back to sRGB to pass to the next shader
    gl_FragColor = vec4(pow(out_color, vec3(1.0 / 2.2)), 1.0);
}
#endif