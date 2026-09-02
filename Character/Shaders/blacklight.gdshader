shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back;

// Global light tracking uniforms
global uniform vec3 uv_light_pos;
global uniform vec3 uv_light_dir;
global uniform float uv_light_angle_cos;
global uniform float uv_light_range;
global uniform float uv_is_editor;

// Local Material Settings
uniform bool preview_mode = false;
uniform vec4 highlight_color : source_color = vec4(0.85, 0.25, 0.95, 1.0);
uniform float black_cutoff : hint_range(0.0, 1.0) = 0.15;
uniform float chalk_grain_amount : hint_range(0.0, 1.0) = 0.35;

// Lowered default glow intensity and scaled slider range for subtle emission
uniform float glow_intensity : hint_range(0.0, 2.0) = 0.2; 

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec4 base_color : source_color = vec4(1.0);

varying vec3 world_position;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 base_tex = texture(albedo_texture, UV) * base_color;

	// 1. Cut off black background pixels completely
	float luminance = dot(base_tex.rgb, vec3(0.299, 0.587, 0.114));
	if (luminance < black_cutoff) {
		discard;
	}

	// 2. Editor-only preview check
	bool active_preview = preview_mode && (uv_is_editor > 0.5);

	// 3. Check spotlight cone boundaries
	float in_cone = 0.0;

	if (active_preview) {
		in_cone = 1.0;
	} else if (uv_light_range > 0.001) {
		vec3 light_to_frag = world_position - uv_light_pos;
		float dist = length(light_to_frag);

		if (dist <= uv_light_range) {
			vec3 dir_to_frag = light_to_frag / dist;
			float current_cos = dot(dir_to_frag, normalize(uv_light_dir));

			float angle_mask = smoothstep(uv_light_angle_cos - 0.03, uv_light_angle_cos + 0.01, current_cos);
			float dist_mask = 1.0 - smoothstep(uv_light_range * 0.8, uv_light_range, dist);

			in_cone = angle_mask * dist_mask;
		}
	}

	// 4. Hide completely if unlit
	if (in_cone <= 0.01) {
		discard;
	}

	// 5. Apply grain filter and controlled light output
	float grain = rand(UV * 250.0);
	float grain_mask = mix(1.0, grain, chalk_grain_amount);

	vec3 final_color = highlight_color.rgb * base_tex.rgb * grain_mask;

	ALBEDO = final_color;
	// Softened glow output
	EMISSION = final_color * glow_intensity * in_cone;
	ALPHA = in_cone * highlight_color.a * smoothstep(black_cutoff, black_cutoff + 0.1, luminance);
}