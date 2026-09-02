shader_type particles;

uniform float spawn_rate = 30.0;
uniform float lifetime_min = 1.0;
uniform float lifetime_max = 3.0;
uniform float velocity_min = 5.0;
uniform float velocity_max = 20.0;
uniform float cone_angle_max = 45.0;
uniform float origin_sphere_radius = 15.0;
uniform float sprite_size_min = 2.0;
uniform float sprite_size_max = 4.0;
uniform float color_intensity_scale = 2.0;
uniform float gravity = 0.5;
uniform float damping = 1.5;
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
	
	float radius = origin_sphere_radius * 0.01;
	vec3 sphere_pos = normalize(rand * 2.0 - 1.0) * radius * rand2.x;
	
	TRANSFORM = EMISSION_TRANSFORM;
	TRANSFORM[3].xyz += sphere_pos;
	
	float cone_rad = radians(cone_angle_max);
	float theta = rand2.y * TAU;
	float phi = rand2.z * cone_rad;
	vec3 dir = vec3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta));
	
	dir = (EMISSION_TRANSFORM * vec4(dir, 0.0)).xyz;
	
	float speed = mix(velocity_min, velocity_max, rand.y) * 0.01;
	VELOCITY = dir * speed;
	
	float size = mix(sprite_size_min, sprite_size_max, rand.z) * 0.005;
	TRANSFORM[0].x = size;
	TRANSFORM[1].y = size;
	TRANSFORM[2].z = size;
	
	COLOR.rgb = mix(vec3(1.0, 0.4, 0.05), vec3(1.0, 0.7, 0.15), rand2.x) * color_intensity_scale;
	COLOR.a = 1.0;
}

void process() {
	CUSTOM.y += DELTA;
	float normalized_age = clamp(CUSTOM.y / CUSTOM.x, 0.0, 1.0);
	
	if (CUSTOM.y >= CUSTOM.x) {
		ACTIVE = false;
	}
	
	float alpha = texture(alpha_curve, vec2(normalized_age, 0.0)).r;
	COLOR.a = alpha;
	
	float size_mult = texture(size_curve, vec2(normalized_age, 0.0)).r;
	float base_size = mix(sprite_size_min, sprite_size_max, 0.5) * 0.005;
	float new_size = base_size * (size_mult / 50.0);
	
	TRANSFORM[0].x = new_size;
	TRANSFORM[1].y = new_size;
	TRANSFORM[2].z = new_size;
	
	VELOCITY.y += gravity * DELTA;
	VELOCITY *= exp(-damping * DELTA);
}