shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

uniform sampler2D depth_texture : hint_depth_texture;

// Текстуры декали
uniform sampler2D shape_tex : source_color, repeat_enable;  // T_AshParticleShape
uniform sampler2D noise_tex : source_color, repeat_enable;  // T_Noise_8
uniform sampler2D fire_tex  : source_color, repeat_enable;  // T_Fireball_OuterShell_BaseColor

// UV-параметры
uniform vec2 shape_scale = vec2(1.0);
uniform vec2 noise_scale = vec2(1.0);
uniform vec2 fire_scale  = vec2(1.0);

// Эффекты
uniform float erosion : hint_range(0.0, 1.0) = 0.0;
uniform float contrast : hint_range(0.0, 1.0) = 0.75;
uniform float ccontrast : hint_range(0.0, 1.0) = 0.3;

uniform vec4 burn_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 embers_color : source_color = vec4(4.0, 1.0, 0.0, 1.0);
uniform float emission_energy : hint_range(0.0, 50.0) = 5.0;

uniform float rotation_degrees : hint_range(0.0, 360.0) = 0.0;

vec2 rotate_uv(vec2 uv, float angle_deg) {
    float rad = radians(angle_deg);
    float s = sin(rad), c = cos(rad);
    return vec2(uv.x * c - uv.y * s, uv.x * s + uv.y * c);
}

float cheap_contrast(float x, float c) {
    return 0.5 + (x - 0.5) * c;
}

void fragment() {
    // Читаем глубину сцены под этим пикселем Quad'а
    float depth = texture(depth_texture, SCREEN_UV).r;
    if (depth >= 0.999999) discard; // ничего нет — не рисуем

    // Восстанавливаем мировую позицию
    vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
    vec4 view_pos = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
    view_pos.xyz /= view_pos.w;
    vec4 world_pos = INV_VIEW_MATRIX * vec4(view_pos.xyz, 1.0);
    vec3 local_pos = (inverse(MODEL_MATRIX) * world_pos).xyz;

    // Quad имеет размер 1x1 по X и Y в локальных координатах (от -0.5 до 0.5)
    if (abs(local_pos.x) > 0.5 || abs(local_pos.y) > 0.5) discard;

    // Нормализуем UV (0..1)
    vec2 uv = local_pos.xy + 0.5;

    // Поворот и масштабирование
    vec2 uv_rot = rotate_uv(uv - 0.5, rotation_degrees) + 0.5;
    vec2 s_uv = (uv_rot - 0.5) * shape_scale + 0.5;
    vec2 n_uv = (uv_rot - 0.5) * noise_scale + 0.5;
    vec2 f_uv = (uv_rot - 0.5) * fire_scale  + 0.5;

    float shape = texture(shape_tex, s_uv).r;
    float noise = texture(noise_tex, n_uv).r;
    float fire  = texture(fire_tex,  f_uv).r;

    // Логика M_FlareBurnDecal
    float fire_contrasted = cheap_contrast(fire, ccontrast);
    float fire_glow_mask = smoothstep(erosion, erosion + (1.0 - contrast), fire_contrasted);
    float final_emission_mask = fire_glow_mask * noise * shape;

    ALBEDO = burn_color.rgb;
    EMISSION = embers_color.rgb * final_emission_mask * emission_energy;

    float alpha = shape * fire;
    ALPHA = clamp(alpha, 0.0, 1.0);
}