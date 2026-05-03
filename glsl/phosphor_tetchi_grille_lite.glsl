// Parameter declaration for RetroArch UI 
// (Must be inside FRAGMENT or global scope for GLSL parser)
#pragma parameter MASK_SCALE "Phosphor Mask Scale" 1.0 1.0 4.0 1.0

#if defined(VERTEX)
#if __VERSION__ >= 130
#define COMPAT_VARYING out
#define COMPAT_ATTRIBUTE in
#define COMPAT_TEXTURE texture
#else
#define COMPAT_VARYING varying
#define COMPAT_ATTRIBUTE attribute
#define COMPAT_TEXTURE texture2D
#endif

COMPAT_ATTRIBUTE vec4 VertexCoord;
COMPAT_ATTRIBUTE vec4 TexCoord;
COMPAT_VARYING vec2 vTexCoord;
uniform mat4 MVPMatrix;

void main() { gl_Position = MVPMatrix * VertexCoord; vTexCoord = TexCoord.xy; }

#elif defined(FRAGMENT)
#if __VERSION__ >= 130
#define COMPAT_VARYING in
#define COMPAT_TEXTURE texture
out vec4 FragColor;
#else
#define COMPAT_VARYING varying
#define FragColor gl_FragColor
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
// Force mediump for performance on low-end APUs (e.g., PS Classic)
precision mediump float; 
#endif

COMPAT_VARYING vec2 vTexCoord;
uniform sampler2D Texture;
uniform vec2 OutputSize;

#ifdef PARAMETER_UNIFORM
uniform float MASK_SCALE;
#else
#define MASK_SCALE 1.0
#endif

void main() {
    // Fast linear conversion (Gamma 2.0) using multiplication
    vec3 raw_color = COMPAT_TEXTURE(Texture, vTexCoord).rgb;
    vec3 center_color = raw_color * raw_color; 
    
    // Physically accurate linear luminance weights
    float luminance = dot(center_color, vec3(0.2126, 0.7152, 0.0722));

    // Slightly reduced bloom radius for better texture cache hit rate on low-end devices
    float radius = (luminance * 1.5) / OutputSize.x; 
    
    vec3 bloom_color = vec3(0.0);
    
    // [Ultra-light Optimization] Sample and immediately apply fast linear conversion
    vec3 s1 = COMPAT_TEXTURE(Texture, vTexCoord + vec2(-radius * 2.0, 0.0)).rgb; bloom_color += (s1 * s1) * 0.06;
    vec3 s2 = COMPAT_TEXTURE(Texture, vTexCoord + vec2(-radius, 0.0)).rgb;       bloom_color += (s2 * s2) * 0.24;
    bloom_color += center_color * 0.40;
    vec3 s3 = COMPAT_TEXTURE(Texture, vTexCoord + vec2(radius, 0.0)).rgb;        bloom_color += (s3 * s3) * 0.24;
    vec3 s4 = COMPAT_TEXTURE(Texture, vTexCoord + vec2(radius * 2.0, 0.0)).rgb;  bloom_color += (s4 * s4) * 0.06;

    // Global brightness boost (1.1x in linear space, prevents clipping)
    bloom_color *= 1.1; 

    // ----------------------------------------------------
    // RGB Phosphor Mask Generation (Aperture Grille)
    // ----------------------------------------------------
    float mask_pos = fract((vTexCoord.x * OutputSize.x) / (3.0 * MASK_SCALE));
    vec3 mask = vec3(0.0);
    
    // Base mask brightness raised to 0.7 to prevent crushed blacks in linear space
    float mask_base = 0.7; 
    
    if (mask_pos < 0.333) mask = vec3(1.0, mask_base, mask_base);
    else if (mask_pos < 0.666) mask = vec3(mask_base, 1.0, mask_base);
    else mask = vec3(mask_base, mask_base, 1.0);

    vec3 final_color = bloom_color * mask;

    // Linear Contrast adjustment (toned down from 1.3 to 1.1 to avoid over-saturation)
    final_color = (final_color - 0.5) * 1.1 + 0.5;
    
    // [Ultra-light Optimization] 
    // Fast sRGB re-compression using sqrt() for final monitor output
    final_color = sqrt(max(final_color, 0.0));

    FragColor = vec4(final_color, 1.0);
}
#endif