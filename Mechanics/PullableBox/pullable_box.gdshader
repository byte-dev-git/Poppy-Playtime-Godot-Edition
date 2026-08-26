shader_type spatial;

// Base Material Maps
uniform sampler2D base_albedo : source_color;
uniform sampler2D base_normal : hint_normal;
uniform sampler2D base_orm; // R: AO, G: Roughness, B: Metallic

// Layer Material Maps
uniform sampler2D layer_albedo : source_color;
uniform sampler2D layer_normal : hint_normal;
uniform sampler2D layer_orm; // R: AO, G: Roughness, B: Metallic

// Global Edge Softness
uniform float edge_softness : hint_range(0.001, 0.05) = 0.005;

// Front (+Z) Controls
uniform bool enable_front = true;
uniform vec2 front_center = vec2(0.0, 0.0);
uniform vec2 front_size = vec2(1.0, 1.0);
uniform float front_radius = 0.1;

// Back (-Z) Controls
uniform bool enable_back = false;
uniform vec2 back_center = vec2(0.0, 0.0);
uniform vec2 back_size = vec2(1.0, 1.0);
uniform float back_radius = 0.1;

// Right (+X) Controls
uniform bool enable_right = false;
uniform vec2 right_center = vec2(0.0, 0.0);
uniform vec2 right_size = vec2(1.0, 1.0);
uniform float right_radius = 0.1;

// Left (-X) Controls
uniform bool enable_left = false;
uniform vec2 left_center = vec2(0.0, 0.0);
uniform vec2 left_size = vec2(1.0, 1.0);
uniform float left_radius = 0.1;

// Top (+Y) Controls
uniform bool enable_top = false;
uniform vec2 top_center = vec2(0.0, 0.0);
uniform vec2 top_size = vec2(1.0, 1.0);
uniform float top_radius = 0.1;

// Bottom (-Y) Controls
uniform bool enable_bottom = false;
uniform vec2 bottom_center = vec2(0.0, 0.0);
uniform vec2 bottom_size = vec2(1.0, 1.0);
uniform float bottom_radius = 0.1;

varying vec3 local_pos;
varying vec3 local_norm;

void vertex() {
    local_pos = VERTEX;
    local_norm = NORMAL;
}

float sd_rounded_box(vec2 p, vec2 half_size, float radius) {
    vec2 q = abs(p) - half_size + vec2(radius);
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - radius;
}

float calc_mask(vec2 pos, vec2 center, vec2 size, float radius) {
    vec2 p = pos - center;
    vec2 half_size = size * 0.5;
    float max_r = min(half_size.x, half_size.y);
    float r = min(radius, max_r);
    float dist = sd_rounded_box(p, half_size, r);
    return 1.0 - smoothstep(-edge_softness, 0.0, dist);
}

void fragment() {
    vec3 abs_norm = abs(local_norm);
    float mask = 0.0;

    // Detect dominant face side based on normal direction
    if (abs_norm.z >= abs_norm.x && abs_norm.z >= abs_norm.y) {
        if (local_norm.z > 0.0 && enable_front) {
            mask = calc_mask(local_pos.xy, front_center, front_size, front_radius);
        } else if (local_norm.z < 0.0 && enable_back) {
            mask = calc_mask(vec2(-local_pos.x, local_pos.y), back_center, back_size, back_radius);
        }
    } else if (abs_norm.x >= abs_norm.y) {
        if (local_norm.x > 0.0 && enable_right) {
            mask = calc_mask(vec2(-local_pos.z, local_pos.y), right_center, right_size, right_radius);
        } else if (local_norm.x < 0.0 && enable_left) {
            mask = calc_mask(local_pos.zy, left_center, left_size, left_radius);
        }
    } else {
        if (local_norm.y > 0.0 && enable_top) {
            mask = calc_mask(local_pos.xz, top_center, top_size, top_radius);
        } else if (local_norm.y < 0.0 && enable_bottom) {
            mask = calc_mask(local_pos.xz, bottom_center, bottom_size, bottom_radius);
        }
    }

    // Sample Textures
    vec3 b_albedo = texture(base_albedo, UV).rgb;
    vec3 b_normal = texture(base_normal, UV).rgb;
    vec3 b_orm    = texture(base_orm, UV).rgb;

    vec3 l_albedo = texture(layer_albedo, UV).rgb;
    vec3 l_normal = texture(layer_normal, UV).rgb;
    vec3 l_orm    = texture(layer_orm, UV).rgb;

    // Blend PBR Outputs
    ALBEDO     = mix(b_albedo, l_albedo, mask);
    NORMAL_MAP = mix(b_normal, l_normal, mask);
    
    vec3 blended_orm = mix(b_orm, l_orm, mask);
    AO        = blended_orm.r;
    ROUGHNESS = blended_orm.g;
    METALLIC  = blended_orm.b;
}