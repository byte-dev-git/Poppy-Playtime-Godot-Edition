shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

// === Snowflakes visual - MI_Embers_01 reused with ice colors ===
// 2x2 flipbook, velocity-aligned sparkle

uniform sampler2D snowflake_texture : source_color, filter_linear_mipmap;
uniform float emission_strength = 2.0;
uniform int columns = 2;
uniform int rows = 2;

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
	int total_frames = columns * rows;
	float normalized_age = instance_custom.y / max(instance_custom.x, 0.001);
	float frame_f = normalized_age * float(total_frames - 1);
	
	int frame0 = int(floor(frame_f));
	int frame1 = min(frame0 + 1, total_frames - 1);
	float blend = fract(frame_f);
	
	vec2 frame_size = vec2(1.0 / float(columns), 1.0 / float(rows));
	
	int col0 = frame0 % columns;
	int row0 = frame0 / columns;
	vec2 uv0 = UV * frame_size + vec2(float(col0), float(row0)) * frame_size;
	
	int col1 = frame1 % columns;
	int row1 = frame1 / columns;
	vec2 uv1 = UV * frame_size + vec2(float(col1), float(row1)) * frame_size;
	
	vec4 tex0 = texture(snowflake_texture, uv0);
	vec4 tex1 = texture(snowflake_texture, uv1);
	vec4 tex = mix(tex0, tex1, blend);
	
	// Use luminance, color from particle
	float luminance = max(tex.r, max(tex.g, tex.b));
	
	// Procedural fallback - glowing dot
	float dist = length(UV - 0.5) * 2.0;
	float glow = exp(-dist * dist * 4.0);
	float alpha_mask = mix(glow, luminance, step(0.01, tex.a));
	
	ALBEDO = COLOR.rgb * emission_strength * alpha_mask;
	ALPHA = COLOR.a * alpha_mask;
}
