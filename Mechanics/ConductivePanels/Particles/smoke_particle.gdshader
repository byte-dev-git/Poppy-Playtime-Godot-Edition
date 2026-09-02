shader_type particles;

// === Stationary fire bursts - small, slow, tight area ===

uniform float lifetime_min = 1.0;
uniform float lifetime_max = 2.0;
uniform float sprite_size_min = 1.0;
uniform float sprite_size_max = 3.0;
uniform float alpha_min = 0.3;
uniform float alpha_max = 0.5;
uniform float color_intensity = 80.0;
uniform float spawn_area = 0.03;
uniform sampler2D alpha_curve : filter_linear;
uniform sampler2D scale_curve : filter_linear;

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

vec3 hash3(float n) {
	return vec3(hash(n), hash(n + 1.0), hash(n + 2.0));
}

void start() {
	float idx = float(INDEX);
	vec3 rand = hash3(idx * 23.1 + TIME * 0.15);
	vec3 rand2 = hash3(idx * 41.3 + TIME * 0.25);
	
	CUSTOM.x = mix(lifetime_min, lifetime_max, rand.x);
	CUSTOM.y = 0.0;
	CUSTOM.z = rand2.y;
	
	// Tight spawn area
	TRANSFORM[3].xyz = vec3(
		(rand.x - 0.5) * spawn_area,
		0.0,
		(rand.z - 0.5) * spawn_area
	);
	
	// No velocity
	VELOCITY = vec3(0.0, 0.0, 0.0);
	
	// Small size
	float size = mix(sprite_size_min, sprite_size_max, rand2.x) * 0.01;
	TRANSFORM[0].x = size;
	TRANSFORM[1].y = size;
	TRANSFORM[2].z = size;
	
	COLOR.a = mix(alpha_min, alpha_max, rand.z);
	
	float fire_rand = rand2.z;
	COLOR.rgb = mix(
    vec3(1.0, 0.08, 0.0),
    vec3(1.0, 0.25, 0.02),
    fire_rand
) * color_intensity * 0.01;
}

void process() {
	CUSTOM.y += DELTA;
	float normalized_age = clamp(CUSTOM.y / CUSTOM.x, 0.0, 1.0);
	
	if (CUSTOM.y >= CUSTOM.x) {
		ACTIVE = false;
	}
	
	float alpha_life = texture(alpha_curve, vec2(normalized_age, 0.0)).r;
	COLOR.a = mix(alpha_min, alpha_max, 0.5) * alpha_life;
	
	float scale_life = texture(scale_curve, vec2(normalized_age, 0.0)).r;
	float base_size = mix(sprite_size_min, sprite_size_max, 0.5) * 0.01;
	float s = base_size * scale_life;
	TRANSFORM[0].x = s;
	TRANSFORM[1].y = s;
	TRANSFORM[2].z = s;
	
	COLOR.rgb = mix(
		COLOR.rgb,
		vec3(0.4, 0.1, 0.02) * color_intensity * 0.005,
		normalized_age * 0.3
	);
}