shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

// === MI_Embers_01 material recreation ===
// UE: SubImageSize 2x2, VelocityAligned sprite
// Additive blending for hot glowing embers

uniform sampler2D ember_texture : source_color, filter_linear_mipmap;
uniform float emission_strength = 3.0;
uniform bool use_sub_images = true;
uniform vec2 sub_image_size = vec2(2.0, 2.0);

varying float v_normalized_age;

void vertex() {
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
	vec2 uv = UV;
	
	// Sub-image animation (2x2 flipbook)
	if (use_sub_images) {
		// Use INSTANCE_CUSTOM.y / INSTANCE_CUSTOM.x for normalized age
		float frame = floor(COLOR.a * 3.99); // 4 frames
		float col = mod(frame, sub_image_size.x);
		float row = floor(frame / sub_image_size.x);
		uv = (uv + vec2(col, row)) / sub_image_size;
	}
	
	vec4 tex = texture(ember_texture, uv);
	
	// If no texture, generate procedural ember dot
	float dist = length(UV - 0.5) * 2.0;
	float glow = exp(-dist * dist * 4.0);
	vec3 procedural = COLOR.rgb * glow;
	
	ALBEDO = mix(procedural, tex.rgb * COLOR.rgb, tex.a) * emission_strength;
	ALPHA = COLOR.a * max(glow, tex.a);
}
