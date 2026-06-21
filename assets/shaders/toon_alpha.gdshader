// ============================================================================
//  toon_alpha.gdshader — ПРОЗРАЧНЫЙ тун-материал (стекло, вода, зоны-подсветки).
//  То же освещение, что в toon.gdshader, но с альфа-смешиванием.
//  Зачем отдельный файл: прозрачность в Godot нельзя включить «на лету» — шейдер,
//  который пишет в ALPHA, ВСЕГДА идёт в прозрачную очередь рендера. Поэтому
//  непрозрачные объекты держим на toon.gdshader (быстрее, без артефактов сортировки).
//  Фабрика Look.gd сама выбирает этот шейдер, если у цвета alpha < 1.
//  Контур к прозрачному обычно НЕ вешаем (Look.gd по умолчанию его выключает).
// ============================================================================
shader_type spatial;
// cull_disabled — у стекла/воды должно быть видно обе стороны.
render_mode cull_disabled;

#include "res://assets/shaders/toon_light.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 0.5);
uniform sampler2D tex : source_color, hint_default_white, filter_linear_mipmap;
uniform float bands : hint_range(2.0, 5.0) = 3.0;

void fragment() {
	vec4 c = albedo * texture(tex, UV);
	ALBEDO = c.rgb;
	ALPHA = c.a;       // <- из-за записи в ALPHA материал и становится прозрачным
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	DIFFUSE_LIGHT += toon_diffuse(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, ALBEDO, bands);
}
