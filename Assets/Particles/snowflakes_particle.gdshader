shader_type particles;

// === NS_CHPanel_ChilledPowerIdle - Snowflakes ===
// Small ice/snow particles falling around chilled panel
// Uses MI_Embers_01 material (2x2 flipbook, velocity-aligned)

uniform float spawn_rate = 30.0;
uniform float lifetime_min = 1.0;
uniform float lifetime_max = 3.0;
uniform float velocity_min = 5.0;
uniform float velocity_max = 15.0;
uniform float cone_angle_max = 60.0;
uniform float origin_sphere_radius = 20.0;
uniform float sprite_size_min = 1.0;
uniform float sprite_size_max = 3.0;
uniform float color_intensity_scale = 1.5;
uniform sampler2D alpha_curve : filter_linear;
uniform sampler2D size_curve : filter_linear;

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

vec3 hash3(float n) {
	return vec3(hash(n), hash(n + 1.0), hash(n + 2.0));
}

void start() {
	float idx = float(INDEX);
	vec3 rand = hash3(idx * 17.3 + TIME * 0.1);
	vec3 rand2 = hash3(idx * 31.7 + TIME * 0.3);
	
	CUSTOM.x = mix(lifetime_min, lifetime_max, rand.x);
	CUSTOM.y = 0.0;
	
	// Spawn in sphere around panel
	float radius = origin_sphere_radius * 0.01;
	vec3 sphere_pos = normalize(rand * 2.0 - 1.0) * radius * rand2.x;
	TRANSFORM[3].xyz = sphere_pos;
	
	// Downward cone - snow falls DOWN (Y-)
	float cone_rad = radians(cone_angle_max);
	float theta = rand2.y * TAU;
	float phi = rand2.z * cone_rad;
	vec3 dir = vec3(sin(phi) * cos(theta), -cos(phi), sin(phi) * sin(theta));
	float speed = mix(velocity_min, velocity_max, rand.y) * 0.01;
	VELOCITY = dir * speed;
	
	// Small snowflake size
	float size = mix(sprite_size_min, sprite_size_max, rand.z) * 0.005;
	TRANSFORM[0].x = size;
	TRANSFORM[1].y = size;
	TRANSFORM[2].z = size;
	
	// Ice blue-white color
	float color_rand = rand2.x;
	COLOR.rgb = mix(
		vec3(0.7, 0.85, 1.0),   // light blue
		vec3(0.95, 0.97, 1.0),  // almost white
		color_rand
	) * color_intensity_scale;
	COLOR.a = 1.0;
}

void process() {
	CUSTOM.y += DELTA;
	float lifetime = CUSTOM.x;
	float normalized_age = clamp(CUSTOM.y / lifetime, 0.0, 1.0);
	
	if (CUSTOM.y >= lifetime) {
		ACTIVE = false;
	}
	
	// Alpha: fade in -> hold -> fade out
	float alpha = texture(alpha_curve, vec2(normalized_age, 0.0)).r;
	COLOR.a = alpha;
	
	// Size shrinks
	float size_mult = texture(size_curve, vec2(normalized_age, 0.0)).r;
	float size_factor = size_mult / 50.0;
	float base_size = mix(sprite_size_min, sprite_size_max, 0.5) * 0.005;
	float new_size = base_size * max(size_factor, 0.05);
	TRANSFORM[0].x = new_size;
	TRANSFORM[1].y = new_size;
	TRANSFORM[2].z = new_size;
	
	// Gentle drift + slight gravity
	VELOCITY.y -= 0.01 * DELTA;
	VELOCITY.x += sin(TIME * 2.0 + float(INDEX) * 0.7) * 0.001;
	VELOCITY.z += cos(TIME * 1.5 + float(INDEX) * 1.1) * 0.001;
}
