shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler3D lut_1 : filter_linear;
uniform sampler3D lut_2 : filter_linear;
uniform float lut_size = 32.0;
uniform float blend_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 screen_color = texture(SCREEN_TEXTURE, SCREEN_UV);
    vec3 raw_rgb = screen_color.rgb;

    float scale = (lut_size - 1.0) / lut_size;
    float offset = 1.0 / (2.0 * lut_size);
    vec3 lut_coords = raw_rgb * scale + offset;

    vec3 color_1 = texture(lut_1, lut_coords).rgb;
    vec3 color_2 = texture(lut_2, lut_coords).rgb;

    vec3 final_color = mix(color_1, color_2, blend_amount);

    COLOR = vec4(final_color, screen_color.a);
}
