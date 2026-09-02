shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, depth_test_disabled;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D distortion_noise : filter_linear_mipmap, repeat_enable;
uniform float distortion_strength = 0.02;
uniform float noise_scale = 2.0;
uniform float scroll_speed = 0.5;

varying vec4 instance_custom;

void vertex() {
	instance_custom = INSTANCE_CUSTOM;
	MODELVIEW_MATRIX = VIEW_MATRIX * MODEL_MATRIX;
	MODELVIEW_MATRIX[0][0] = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX[0][1] = 0.0;
	MODELVIEW_MATRIX[0][2] = 0.0;
	MODELVIEW_MATRIX[1][0] = 0.0;
	MODELVIEW_MATRIX[1][1] = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX[1][2] = 0.0;
	MODELVIEW_MATRIX[2][0] = 0.0;
	MODELVIEW_MATRIX[2][1] = 0.0;
	MODELVIEW_MATRIX[2][2] = length(MODEL_MATRIX[2].xyz);
}

void fragment() {
	float dist = length(UV - 0.5) * 2.0;
	float circle_mask = smoothstep(1.0, 0.3, dist) * smoothstep(0.0, 0.1, 1.0 - dist);
	
	vec2 noise_uv = UV * noise_scale + vec2(0.0, -TIME * scroll_speed);
	float dx = sin(noise_uv.x * 10.0 + TIME * 2.0);
	float dy = cos(noise_uv.y * 10.0 + TIME * 1.5);
	vec2 offset = vec2(dx, dy) * distortion_strength * circle_mask * COLOR.a;
	
	vec3 screen_color = texture(screen_texture, SCREEN_UV + offset).rgb;
	ALBEDO = screen_color;
	ALPHA = circle_mask * circle_mask;
	
	// Discard pixels at edges to prevent dark squares
	if (circle_mask < 0.05) {
		discard;
	}
}