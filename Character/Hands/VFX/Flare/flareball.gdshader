shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec4 base_color : source_color = vec4(1.0, 0.4, 0.0, 1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;

uniform float scroll_speed : hint_range(0.0, 2.0) = 0.2;
uniform float emission_strength = 2.0;
uniform float rim_power = 3.0;     
uniform float rim_intensity = 3.0; 

void fragment() {
    vec2 moving_uv = UV + vec2(TIME * scroll_speed * 0.5, TIME * scroll_speed);
    
    vec4 tex_color = texture(albedo_tex, moving_uv);
    ALBEDO = tex_color.rgb * base_color.rgb;
    
    NORMAL_MAP = texture(normal_tex, moving_uv).rgb;
    
    float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
    
    vec3 rim_glow = base_color.rgb * fresnel * rim_intensity;
    EMISSION = (ALBEDO * emission_strength) + rim_glow;
}
