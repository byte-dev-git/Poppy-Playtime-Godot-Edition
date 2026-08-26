shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform sampler3D lut_texture : filter_linear, repeat_disable;
uniform float lut_size = 64.0;

void fragment() {
    // 1. Получаем исходный цвет экрана
    vec4 screen_color = texture(screen_texture, SCREEN_UV);
    
    // 2. Ограничиваем диапазон (важно для корректной выборки из LUT)
    // Масштабируем 0.0-1.0 в диапазон (0.5/size) - ((size-0.5)/size)
    vec3 lut_coords = screen_color.rgb * ((lut_size - 1.0) / lut_size) + (0.5 / lut_size);
    
    // 3. Выборка из 3D текстуры
    vec3 corrected_color = texture(lut_texture, lut_coords).rgb;
    
    COLOR = vec4(corrected_color, screen_color.a);
}
