shader_type particles;

// === NS_CHPanel_HeatPowerIdle - NE_HeatDistortion_High emitter ===
// Screen-space heat shimmer effect
// UE: MI_BunsenBurnerGas material, ring spawn, large sprites

uniform float spawn_rate = 2.0;
uniform float lifetime_min = 1.0;
uniform float lifetime_max = 1.75;
uniform float origin_ring_radius = 100.0; // UE units
uniform float sprite_size = 50.0; // UE units

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

vec3 hash3(float n) {
	return vec3(hash(n), hash(n + 1.0), hash(n + 2.0));
}

void start() {
	float idx = float(INDEX);
	vec3 rand = hash3(idx * 13.7 + TIME * 0.2);
	
	CUSTOM.x = mix(lifetime_min, lifetime_max, rand.x);
	CUSTOM.y = 0.0;
	
	// Ring spawn (UE: HD_OriginRingRadius = 100 = 1m)
	float angle = rand.y * TAU;
	float r = origin_ring_radius * 0.01;
	TRANSFORM[3].xyz = vec3(cos(angle) * r, 0.0, sin(angle) * r);
	
	// Large sprite size
	float size = sprite_size * 0.01;
	TRANSFORM[0].x = size;
	TRANSFORM[1].y = size;
	TRANSFORM[2].z = size;
	
	// Slow upward drift
	VELOCITY = vec3(0.0, 0.05, 0.0);
	
	// Alpha stored for distortion strength
	COLOR.a = 1.0;
}

void process() {
	CUSTOM.y += DELTA;
	float normalized_age = clamp(CUSTOM.y / CUSTOM.x, 0.0, 1.0);
	
	if (CUSTOM.y >= CUSTOM.x) {
		ACTIVE = false;
	}
	
	// Fade in and out (curve: 0.97→1.0, gentle)
	float alpha = sin(normalized_age * PI);
	COLOR.a = alpha * 0.3; // subtle distortion
	
	// Scale up slightly over lifetime (1.0→1.3)
	float scale_mult = mix(1.0, 1.3, normalized_age);
	float base = sprite_size * 0.01;
	float s = base * scale_mult;
	TRANSFORM[0].x = s;
	TRANSFORM[1].y = s;
	TRANSFORM[2].z = s;
}
