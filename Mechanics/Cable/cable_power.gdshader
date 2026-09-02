shader_type spatial;
render_mode cull_disabled;

group_uniforms Base_Properties;
uniform vec4 color_base : source_color = vec4(0.08, 0.08, 0.08, 1.0);
uniform vec4 color_stripe : source_color = vec4(1.0, 0.1, 0.1, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.4;
// Defines the total length of the continuous UV coordinates
uniform float cable_length = 1.0; 

group_uniforms Pattern_Control;
uniform float frequency : hint_range(1.0, 50.0) = 10.0;
uniform float stripe_ratio : hint_range(0.01, 0.99) = 0.5;
uniform float stripe_softness : hint_range(0.001, 0.5) = 0.08;
uniform float speed = 1.5;
uniform bool invert_direction = false;
uniform bool use_uv_x = false;

group_uniforms Curtain_Fill;
uniform float fill_amount : hint_range(-0.2, 1.2) = 0.0; 
uniform float fill_feather : hint_range(0.001, 1.0) = 0.15;
uniform int curtain_folds : hint_range(0, 20) = 3; 
uniform float curtain_wave_size : hint_range(0.0, 0.5) = 0.03;

group_uniforms Activation_Tint;
uniform vec4 active_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float active_brightness : hint_range(1.0, 5.0) = 1.5;
uniform float active_emission_energy : hint_range(0.0, 20.0) = 5.0;

group_uniforms Inactive_Emission;
uniform float base_emission_energy : hint_range(0.0, 20.0) = 0.0;

void fragment() {
    float coord = use_uv_x ? UV.x : UV.y;
    float perp_coord = use_uv_x ? UV.y : UV.x;
    float dir = invert_direction ? -1.0 : 1.0;
    
    // Normalize the length so fill_amount 0.0 to 1.0 always covers the whole cable
    float normalized_coord = coord / cable_length;
    
    float continuous_pos = coord * frequency - TIME * speed * dir;
    float stripe_wave = sin(continuous_pos * TAU) * 0.5 + 0.5;
    float stripe_mask = smoothstep(stripe_ratio - stripe_softness, stripe_ratio + stripe_softness, stripe_wave);

    vec3 pattern_albedo = mix(color_base.rgb, color_stripe.rgb, stripe_mask);
    vec3 pattern_emission = color_stripe.rgb * stripe_mask * base_emission_energy;

    float wave_offset = sin(perp_coord * TAU * float(curtain_folds)) * curtain_wave_size;
    
    // Fill mask now uses normalized_coord
    float fill_mask = 1.0 - smoothstep(fill_amount - fill_feather, fill_amount, normalized_coord + wave_offset);

    vec3 active_albedo = pattern_albedo * active_tint.rgb * active_brightness;
    vec3 active_emission = (pattern_albedo * active_tint.rgb) * active_emission_energy;

    ALBEDO = mix(pattern_albedo, active_albedo, fill_mask);
    EMISSION = mix(pattern_emission, active_emission, fill_mask);
    ROUGHNESS = roughness;
}