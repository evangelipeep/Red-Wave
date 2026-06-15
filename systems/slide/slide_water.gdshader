shader_type spatial;
render_mode cull_disabled;
// Текущая вода по жёлобу: красная, бегущая рябь вдоль длины горки.
uniform vec4 color : source_color = vec4(0.85, 0.06, 0.06, 0.8);
uniform float speed = 2.0;

void fragment() {
	float ripple = sin(UV.y * 30.0 + TIME * speed * 6.0) * 0.5 + 0.5;
	ALBEDO = color.rgb;
	ALPHA = clamp(color.a * (0.65 + 0.35 * ripple), 0.0, 1.0);
	EMISSION = color.rgb * (0.15 + 0.25 * ripple);
}
