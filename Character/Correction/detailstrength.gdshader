shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// ======================== ОСНОВНЫЕ ПАРАМЕТРЫ ========================
uniform float detail_strength : hint_range(0.0, 5.0) = 1.5;        // сила локального микро-контраста
uniform float sharpen_amount : hint_range(0.0, 10.0) = 0.3;         // дополнительная резкость (Unsharp Mask)

// ======================== БИЛАТЕРАЛЬНЫЙ ФИЛЬТР (9x9) ========================
uniform float radius : hint_range(0.5, 4.0) = 1.5;                 // масштаб шага выборки
uniform float spatial_sigma : hint_range(0.1, 8.0) = 3.0;          // пространственная сигма
uniform float range_sigma : hint_range(0.01, 2.0) = 0.1;           // сигма по разнице яркости (очень узкая)
uniform float range_clamp : hint_range(0.0, 2.0) = 0.2;            // жёсткий порог: если |ΔL| > range_clamp → вес 0
uniform float blur_pixel_limit : hint_range(1.0, 15.0) = 7.0;      // максимальное расстояние размытия в пикселях

// ======================== ДИНАМИЧЕСКОЕ СЖАТИЕ ========================
uniform float compression_amount : hint_range(0.0, 1.0) = 0.65;    // сила сжатия базового слоя

// ======================== ДЕТАЛИ: КЛЭМПИНГ И КОРИНГ ========================
uniform float detail_clamp_min : hint_range(-1.0, 0.0) = -0.2;      // нижний предел деталей в логах
uniform float detail_clamp_max : hint_range(0.0, 1.0) = 0.2;        // верхний предел деталей в логах
uniform float coring_min : hint_range(0.0, 0.1) = 0.01;             // начало подавления шума (логи)
uniform float coring_max : hint_range(0.0, 0.2) = 0.05;             // конец подавления шума

// ======================== МАСКА ПО ЯРКОСТИ (средние тона) ========================
uniform float luma_mask_center : hint_range(0.0, 1.0) = 0.5;
uniform float luma_mask_falloff : hint_range(0.0, 2.0) = 2.0;

// ======================== УСИЛЕНИЕ БЛИКОВ (защита от металлика) ========================
uniform float specular_boost : hint_range(0.0, 2.0) = 0.3;         // усиление микро-бликов
uniform float specular_threshold : hint_range(0.0, 0.5) = 0.05;    // порог в логах, выше которого считается бликом
uniform float highlight_protection : hint_range(0.0, 1.0) = 0.8;   // общее подавление бликов (0 = нет, 1 = макс)

// ======================== ВОССТАНОВЛЕНИЕ САТУРАЦИИ ========================
uniform float saturation_amount : hint_range(0.0, 2.0) = 0.8;

// ======================== ПОДАВЛЕНИЕ АРТЕФАКТОВ ========================
uniform float clamp_strength : hint_range(0.0, 1.0) = 0.5;
uniform float luminance_threshold : hint_range(0.0, 0.1) = 0.01;   // шумоподавление деталей

// ======================== ПЛЁНОЧНОЕ ЗЕРНО ========================
uniform float grain_strength : hint_range(0.0, 1.0) = 0.03;

// ------------------------------------------------------------------
float get_lum(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// ------------------------------------------------------------------
void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 ps = SCREEN_PIXEL_SIZE * radius;
    const float EPS = 0.001;

    vec3 center_rgb = texture(screen_texture, uv).rgb;
    float L_center = log2(max(get_lum(center_rgb), EPS));

    // ---- 1. БИЛАТЕРАЛЬНЫЙ БАЗОВЫЙ СЛОЙ (9x9) ----
    const int KERNEL_RADIUS = 4;
    float log_base_sum = 0.0;
    float weight_sum = 0.0;

    for (int x = -KERNEL_RADIUS; x <= KERNEL_RADIUS; x++) {
        for (int y = -KERNEL_RADIUS; y <= KERNEL_RADIUS; y++) {
            float pixel_dist = length(vec2(float(x), float(y))) * radius;
            if (pixel_dist > blur_pixel_limit) continue;

            vec2 offset = vec2(float(x), float(y)) * ps;
            vec3 sample_rgb = texture(screen_texture, uv + offset).rgb;
            float sample_log = log2(max(get_lum(sample_rgb), EPS));

            float dist_sq = dot(offset, offset);
            float delta_lum = sample_log - L_center;

            // Жёсткая отсечка по яркости
            if (abs(delta_lum) > range_clamp) continue;

            float w = exp( -dist_sq / (2.0 * spatial_sigma * spatial_sigma)
                          -delta_lum * delta_lum / (2.0 * range_sigma * range_sigma) );

            log_base_sum += sample_log * w;
            weight_sum += w;
        }
    }

    float log_base = log_base_sum / max(weight_sum, 0.0001);

    // ---- 2. ДИНАМИЧЕСКОЕ СЖАТИЕ БАЗЫ ----
    float base_linear = exp2(log_base);
    float base_compressed = base_linear / (base_linear + 1.0);
    base_compressed = mix(base_linear, base_compressed, compression_amount);
    float log_base_compressed = log2(max(base_compressed, EPS));

    // ---- 3. ДЕТАЛИ ----
    float detail = L_center - log_base;

    // Первичное шумоподавление
    float noise_mask = smoothstep(luminance_threshold, luminance_threshold * 2.0, abs(detail));
    detail *= noise_mask;

    // Клэмпинг
    detail = clamp(detail, detail_clamp_min, detail_clamp_max);

    // Мягкий ко́ринг
    detail *= smoothstep(coring_min, coring_max, abs(detail));

    // ---- 4. МАСКА ПО ЯРКОСТИ (строим до усиления) ----
    float base_srgb = clamp(base_linear, 0.0, 1.0);
    float luma_mask = 1.0 - abs(base_srgb - luma_mask_center) * luma_mask_falloff;
    luma_mask = clamp(luma_mask, 0.0, 1.0);

    // ---- 5. УСИЛЕНИЕ МИКРО-БЛИКОВ С ЗАЩИТОЙ ОТ МЕТАЛЛИКА ----
    // Основное усиление деталей с маской яркости
    float main_detail = detail * detail_strength * luma_mask;

    // Эвристика металличности: чем выше яркость и ниже насыщенность, тем сильнее подавление бликов
    float center_sat = length(center_rgb - vec3(get_lum(center_rgb))) / max(get_lum(center_rgb), EPS);
    float sat_mask = smoothstep(0.0, 0.3, center_sat);             // 0 = серый (металл), 1 = цветной (пластик)

    // Подавление в ярких областях, умноженное на насыщенность
    float highlight_suppression = (1.0 - smoothstep(0.5, 0.9, base_srgb)) * sat_mask;
    // Дополнительное ручное подавление highlight_protection (чем выше, тем сильнее давим)
    highlight_suppression = mix(highlight_suppression, 0.0, highlight_protection);

    float highlight = max(detail, 0.0);
    float spec_boost = highlight * specular_boost
                     * smoothstep(specular_threshold, specular_threshold * 2.0, highlight)
                     * highlight_suppression;

    detail = main_detail + spec_boost;

    // ---- 6. СБОРКА НОВОЙ ЯРКОСТИ ----
    float L_new = log_base_compressed + detail;
    float Y_new = exp2(L_new);
    float Y_old = max(get_lum(center_rgb), EPS);
    vec3 detailed_color = center_rgb * (Y_new / Y_old);

    // ---- 7. РЕЗКОСТЬ (UNSHARP MASK) ----
    vec3 tl = texture(screen_texture, uv + vec2(-ps.x, -ps.y)).rgb;
    vec3 tc = texture(screen_texture, uv + vec2( 0.0, -ps.y)).rgb;
    vec3 tr = texture(screen_texture, uv + vec2( ps.x, -ps.y)).rgb;
    vec3 ml = texture(screen_texture, uv + vec2(-ps.x,  0.0)).rgb;
    vec3 mr = texture(screen_texture, uv + vec2( ps.x,  0.0)).rgb;
    vec3 bl = texture(screen_texture, uv + vec2(-ps.x,  ps.y)).rgb;
    vec3 bc = texture(screen_texture, uv + vec2( 0.0,  ps.y)).rgb;
    vec3 br = texture(screen_texture, uv + vec2( ps.x,  ps.y)).rgb;

    float L_tl = log2(max(get_lum(tl), EPS));
    float L_tc = log2(max(get_lum(tc), EPS));
    float L_tr = log2(max(get_lum(tr), EPS));
    float L_ml = log2(max(get_lum(ml), EPS));
    float L_mr = log2(max(get_lum(mr), EPS));
    float L_bl = log2(max(get_lum(bl), EPS));
    float L_bc = log2(max(get_lum(bc), EPS));
    float L_br = log2(max(get_lum(br), EPS));

    float L_blur = (L_center + L_tl + L_tc + L_tr + L_ml + L_mr + L_bl + L_bc + L_br) / 9.0;
    float edge_mask = L_center - L_blur;

    float L_detailed = log2(max(get_lum(detailed_color), EPS));
    float L_sharp = L_detailed + sharpen_amount * 0.2 * edge_mask;
    float Y_sharp = exp2(L_sharp);
    vec3 final_color = detailed_color * (Y_sharp / max(get_lum(detailed_color), EPS));

    // ---- 8. КЛЭМПИНГ ОРЕОЛОВ ----
    vec3 min_neighbor = min(min(min(tl, tc), min(tr, ml)), min(min(mr, bl), min(bc, br)));
    vec3 max_neighbor = max(max(max(tl, tc), max(tr, ml)), max(max(mr, bl), max(bc, br)));
    min_neighbor = min(min_neighbor, center_rgb);
    max_neighbor = max(max_neighbor, center_rgb);

    final_color = mix(clamp(final_color, min_neighbor, max_neighbor), final_color, clamp_strength);
    final_color = clamp(final_color, 0.0, 100.0);

    // ---- 9. ВОССТАНОВЛЕНИЕ САТУРАЦИИ ----
    float luma_ratio = Y_new / Y_old;
    float sat_factor = 1.0 + saturation_amount * max(luma_ratio - 1.0, 0.0);
    vec3 gray = vec3(get_lum(final_color));
    final_color = mix(gray, final_color, sat_factor);

    // ---- 10. ПЛЁНОЧНОЕ ЗЕРНО ----
    float grain = (hash(uv + fract(TIME * 100.0)) - 0.5) * grain_strength;
    final_color += grain;
    final_color = clamp(final_color, 0.0, 1.0);

    COLOR = vec4(final_color, 1.0);
}