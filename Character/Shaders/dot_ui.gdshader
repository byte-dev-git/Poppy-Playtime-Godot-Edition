shader_type canvas_item;

uniform float pixel_size : hint_range(1.0, 50.0, 1.0) = 4.0;
uniform float circle_scale : hint_range(0.1, 1.0) = 0.8;
// Use a very low threshold to catch thin lines
uniform float sensitivity : hint_range(0.01, 1.0) = 0.1;
uniform vec3 dot_color_override = vec3(1.0, 1.0, 1.0);
uniform bool use_original_colors = true;

void fragment() {
    vec2 tex_size = vec2(textureSize(TEXTURE, 0));
    vec2 pixel_coords = UV * tex_size;
    
    // 1. Grid snapping
    vec2 cell_center = (floor(pixel_coords / pixel_size) * pixel_size) + (pixel_size * 0.5);
    vec2 center_uv = cell_center / tex_size;
    
    // 2. "Search" sampling to ensure thin lines (smiles) aren't missed
    // We sample the center, and a few points around it
    vec4 t1 = texture(TEXTURE, center_uv);
    vec4 t2 = texture(TEXTURE, center_uv + vec2(1.0, 1.0) / tex_size);
    vec4 t3 = texture(TEXTURE, center_uv - vec2(1.0, 1.0) / tex_size);
    
    // Combine them to see if this cell should be "on"
    vec4 combined_color = (t1 + t2 + t3) / 3.0;
    float brightness = max(max(combined_color.r, combined_color.g), combined_color.b);
    
    // 3. Hard 'ON/OFF' switch
    float is_on = step(sensitivity, brightness);
    
    // 4. Draw the circle
    float dist = distance(pixel_coords, cell_center);
    float radius = (pixel_size * 0.5) * circle_scale;
    
    // No-blur circle edge
    float circle = 1.0 - step(radius, dist);
    
    // 5. Final output: Solid background, no transparency
    vec3 final_color = vec3(0.0); // Solid Black Background
    
    if (is_on * circle > 0.5) {
        if (use_original_colors) {
            final_color = t1.rgb;
        } else {
            final_color = dot_color_override;
        }
    }
    
    COLOR = vec4(final_color, 1.0);
}