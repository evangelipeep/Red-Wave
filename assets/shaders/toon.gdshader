// ============================================================================
//  toon.gdshader — НЕПРОЗРАЧНЫЙ тун-материал (основной, 95% геометрии).
//  Плоский цвет + ступенчатый свет = картинка в духе Zelda: Wind Waker.
//  Чёрный контур добавляется ОТДЕЛЬНО как next_pass (см. outline.gdshader).
//  Руками шейдер вешать не нужно — материалы собирает фабрика autoload/Look.gd:
//      some.material = Look.mat(Color(...))
// ============================================================================
shader_type spatial;
// cull_back — рисуем только лицевые грани (контур использует cull_front).
// Свет считаем сами в light(), поэтому встроенные diffuse/specular режимы не нужны.
render_mode cull_back;

#include "res://assets/shaders/toon_light.gdshaderinc"

// --- Параметры материала (их выставляет Look.gd через set_shader_parameter) ---
uniform vec4 albedo : source_color = vec4(1.0);                     // базовый цвет
uniform sampler2D tex : source_color, hint_default_white, filter_linear_mipmap;  // текстура (по умолчанию белая = «нет текстуры»)
uniform float bands : hint_range(2.0, 5.0) = 3.0;                  // ступеней света
uniform vec4 emission_color : source_color = vec4(0.0);           // свечение (вывески/неон)
uniform float emission_energy : hint_range(0.0, 8.0) = 0.0;       // сила свечения

void fragment() {
	ALBEDO = albedo.rgb * texture(tex, UV).rgb;
	ROUGHNESS = 1.0;   // матовая поверхность
	SPECULAR = 0.0;    // без бликов — чистые заливки
	EMISSION = emission_color.rgb * emission_energy;
}

void light() {
	// Плоский ambient (из WorldEnvironment) заполняет тень,
	// а сюда добавляем «жёсткое» солнце ступенями.
	DIFFUSE_LIGHT += toon_diffuse(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, ALBEDO, bands);
}
