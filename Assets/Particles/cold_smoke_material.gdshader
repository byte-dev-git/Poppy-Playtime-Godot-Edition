shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded;

uniform sampler2D smoke_texture : filter_linear_mipmap;
uniform sampler2D six_point_tlr : source_color, filter_linear_mipmap;
uniform sampler2D six_point_bbf : source_color, filter_linear_mipmap;
uniform float emission_strength = 1.5;
uniform float erosion_amount = 0.3;
uniform int columns = 8;
uniform int rows = 8;
uniform vec3 light_direction = vec3(0.3, -1.0, 0.2);
uniform vec3 light_color = vec3(0.7, 0.85, 1.0);
uniform float light_intensity = 1.0;
uniform vec3 ambient_color = vec3(0.1, 0.4, 0.6);

varying vec4 instance_custom;
varying vec3 v_light_dir;

void vertex() {
	instance_custom = INSTANCE_CUSTOM;
	v_light_dir = normalize((VIEW_MATRIX * vec4(normalize(light_direction), 0.0)).xyz);
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
	
	float density0 = max(texture(smoke_texture, uv0).r, max(texture(smoke_texture, uv0).g, texture(smoke_texture, uv0).b));
	float density1 = max(texture(smoke_texture, uv1).r, max(texture(smoke_texture, uv1).g, texture(smoke_texture, uv1).b));
	float density = mix(density0, density1, blend);
	
	vec3 tlr0 = texture(six_point_tlr, uv0).rgb;
	vec3 tlr1 = texture(six_point_tlr, uv1).rgb;
	vec3 tlr = mix(tlr0, tlr1, blend);
	
	vec3 bbf0 = texture(six_point_bbf, uv0).rgb;
	vec3 bbf1 = texture(six_point_bbf, uv1).rgb;
	vec3 bbf = mix(bbf0, bbf1, blend);
	
	vec3 light_dir = normalize(v_light_dir);
	float right_light = max(light_dir.x, 0.0);
	float left_light = max(-light_dir.x, 0.0);
	float top_light = max(light_dir.y, 0.0);
	float bottom_light = max(-light_dir.y, 0.0);
	float front_light = max(light_dir.z, 0.0);
	float back_light = max(-light_dir.z, 0.0);
	
	float lit = 0.0;
	lit += tlr.r * right_light;
	lit += tlr.g * top_light;
	lit += tlr.b * left_light;
	lit += bbf.r * front_light;
	lit += bbf.g * bottom_light;
	lit += bbf.b * back_light;
	
	vec3 lit_color = COLOR.rgb * (light_color * lit * light_intensity + ambient_color);
	
	float erode = mix(0.0, erosion_amount, normalized_age);
	float smoke_alpha = smoothstep(erode, erode + 0.15, density);
	
	ALBEDO = lit_color * emission_strength;
	ALPHA = COLOR.a * smoke_alpha;
	
	if (ALPHA < 0.01) { discard; }
}