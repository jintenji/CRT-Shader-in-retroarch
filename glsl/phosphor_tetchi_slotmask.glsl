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
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
#endif

COMPAT_VARYING vec2 vTexCoord;
uniform sampler2D Texture;
uniform vec2 OutputSize;

#pragma parameter MASK_SCALE "Phosphor Mask Scale" 1.0 1.0 4.0 1.0

#ifdef PARAMETER_UNIFORM
uniform float MASK_SCALE;
#else
#define MASK_SCALE 1.0
#endif

void main() {
    // Convert to Linear space from the previous pass/texture
    vec4 raw_color = COMPAT_TEXTURE(Texture, vTexCoord);
    vec3 center_color = pow(raw_color.rgb, vec3(2.2));

    // Physically accurate linear luminance
    float luminance = dot(center_color, vec3(0.2126, 0.7152, 0.0722));

    // Adjusted bloom strength for linear space (3.0 -> 1.5)
    float bloom_strength = 1.5; 
    float radius = (luminance * bloom_strength) / OutputSize.x; 
    
    vec3 bloom_color = vec3(0.0);
    // Convert surrounding pixels to Linear space immediately upon sampling
    bloom_color += pow(COMPAT_TEXTURE(Texture, vTexCoord + vec2(-radius * 2.0, 0.0)).rgb, vec3(2.2)) * 0.06;
    bloom_color += pow(COMPAT_TEXTURE(Texture, vTexCoord + vec2(-radius, 0.0)).rgb, vec3(2.2)) * 0.24;
    bloom_color += center_color * 0.40;
    bloom_color += pow(COMPAT_TEXTURE(Texture, vTexCoord + vec2(radius, 0.0)).rgb, vec3(2.2)) * 0.24;
    bloom_color += pow(COMPAT_TEXTURE(Texture, vTexCoord + vec2(radius * 2.0, 0.0)).rgb, vec3(2.2)) * 0.06;

    // Normalize brightness boost (1.35 -> 1.1) and neutralize white balance
    float brightness_boost = 1.1; 
    vec3 white_balance = vec3(1.0, 1.0, 1.0); 
    bloom_color *= (brightness_boost * white_balance);

    // Slot Mask generation
    float scale = MASK_SCALE;
    vec2 pos = (vTexCoord * OutputSize) / scale;
    float triad_width = 3.0;
    float slot_height = 4.0;

    float column = floor(pos.x / triad_width);
    float stagger = mod(column, 2.0) * 0.5;
    float slot_y = fract((pos.y / slot_height) + stagger);

    float gap_darkness = 0.35;
    float vertical_mask = (slot_y < 0.15 || slot_y > 0.85) ? gap_darkness : 1.0;

    float mask_pos = fract(pos.x / triad_width);
    vec3 mask = vec3(0.0);
    
    // Increase mask base brightness (0.45 -> 0.7) to prevent crushed blacks
    float mask_base = 0.7; 
    
    if (mask_pos < 0.333) mask = vec3(1.0, mask_base, mask_base);
    else if (mask_pos < 0.666) mask = vec3(mask_base, 1.0, mask_base);
    else mask = vec3(mask_base, mask_base, 1.0);

    vec3 final_color = bloom_color * mask * vertical_mask;

    // Remove secondary mask brightness boost (1.15 -> 1.0)
    float mask_brightness = 1.0; 
    final_color *= mask_brightness;

    // Lower extreme contrast to prevent over-saturation (1.45 -> 1.1)
    float contrast = 1.1;
    float midpoint = 0.5;    
    float real_gamma = 2.2;  

    final_color = (final_color - midpoint) * contrast + midpoint;
    
    // Re-compress to sRGB for monitor output
    final_color = pow(max(final_color, 0.0), vec3(1.0 / real_gamma));

    FragColor = vec4(final_color, 1.0);
}
#endif