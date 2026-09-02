shader_type particles;


uniform float lifetime_min = 1.5;
uniform float lifetime_max = 2.0;
uniform float sprite_size_min = 25.0;
uniform float sprite_size_max = 35.0;
uniform float alpha_min = 0.2;
uniform float alpha_max = 0.4;
uniform float color_intensity = 100.0;
uniform vec3 velocity_min = vec3(0.0, 5.0, 0.0);
uniform vec3 velocity_max = vec3(0.0, 10.0, 0.0);
uniform float spawn_area = 0.05;

float hash(float n) {
    return fract(sin(n) * 43758.5453);
}
vec3 hash3(float n) {
    return vec3(hash(n), hash(n + 1.0), hash(n + 2.0));
}

void start() {
    float idx = float(INDEX);
    vec3 rand  = hash3(idx * 23.1 + TIME * 0.15);
    vec3 rand2 = hash3(idx * 41.3 + TIME * 0.25);

    CUSTOM.x = mix(lifetime_min, lifetime_max, rand.x);
    CUSTOM.y = 0.0;

    TRANSFORM[3].xyz = vec3(
        (rand.x - 0.5) * spawn_area,
        0.0,
        (rand.z - 0.5) * spawn_area
    );

    vec3 vel = mix(velocity_min, velocity_max, rand2) * 0.01;
    vel.x += (rand.y - 0.5) * 0.02;
    vel.z += (rand.z - 0.5) * 0.02;
    vel.y *= 0.3;
    vel.y -= 0.01;
    VELOCITY = vel;

    float size = mix(sprite_size_min, sprite_size_max, rand2.x) * 0.01;
    TRANSFORM[0].x = size;
    TRANSFORM[1].y = size;
    TRANSFORM[2].z = size;

    COLOR.a = mix(alpha_min, alpha_max, rand.z);
    COLOR.rgb = mix(
        vec3(0.6, 0.75, 0.9),
        vec3(0.85, 0.9, 1.0),
        rand2.z
    ) * color_intensity * 0.01;
}

void process() {
    CUSTOM.y += DELTA;
    float normalized_age = clamp(CUSTOM.y / CUSTOM.x, 0.0, 1.0);

    if (CUSTOM.y >= CUSTOM.x) {
        ACTIVE = false;
    } else {
        float alpha_life = sin(normalized_age * 3.14159);
        float scale_life = mix(0.3, 1.0, normalized_age);

        COLOR.a = mix(alpha_min, alpha_max, 0.5) * alpha_life;

        float s = mix(sprite_size_min, sprite_size_max, 0.5) * 0.01 * scale_life;
        TRANSFORM[0].x = s;
        TRANSFORM[1].y = s;
        TRANSFORM[2].z = s;

        VELOCITY *= 0.997;

        float t = CUSTOM.y * 1.3 + float(INDEX) * 0.17;
        VELOCITY.x += (fract(t * 127.1) - 0.5) * 0.003;
        VELOCITY.z += (fract(t * 311.7) - 0.5) * 0.003;
    }
}