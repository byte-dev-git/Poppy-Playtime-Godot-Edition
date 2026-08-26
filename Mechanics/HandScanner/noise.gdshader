shader_type canvas_item;

uniform sampler2D noise_texture : repeat_enable, filter_linear_mipmap;

// Line Styling
uniform vec4 line_color : source_color = vec4(0.0, 0.0, 0.0, 1.0); // Set line color
uniform bool use_solid_color = true; // Overrides JPG noise with clean solid lines

// Movement & Scale
uniform vec2 noise_scale = vec2(1.0, 1.0);
uniform vec2 noise_speed = vec2(0.0, 0.0);

// Border Extraction
uniform float border_thickness : hint_range(0.0, 0.5) = 0.12; // Controls line width
uniform float line_softness : hint_range(0.001, 0.2) = 0.03;   // Edge anti-aliasing
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = (UV * noise_scale) + (TIME * noise_speed);
	vec4 noise = texture(noise_texture, uv);
	
	// Read brightness (0.0 = deep black border, 1.0 = white center)
	float brightness = noise.r;
	
	// Isolate dark values only (0.0 up to border_thickness)
	float line_mask = 1.0 - smoothstep(border_thickness, border_thickness + line_softness, brightness);
	
	// Output solid line color or original dark texture color
	vec3 final_color = use_solid_color ? line_color.rgb : noise.rgb;
	
	COLOR = vec4(final_color, line_mask * opacity * line_color.a);
}