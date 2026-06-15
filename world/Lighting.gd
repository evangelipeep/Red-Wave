extends DirectionalLight3D
## Свет дня, привязанный к Clock: утро (прохладный) → полдень (яркий белый) →
## вечер (тёплый оранжевый) → финал «Баллады» (тёмно-красный закат, GDD §финал).
## Парк темнеет к вечеру — это критерий выхода из фазы 1.

@export var world_env: WorldEnvironment

func _process(_delta: float) -> void:
	if not Clock.running:
		return
	var f := Clock.day_fraction
	var elev := sin(f * PI)   # 0 на рассвете/закате, 1 в полдень

	# Солнце: высота по дуге, азимут восток→запад.
	rotation_degrees = Vector3(-(8.0 + 72.0 * elev), lerpf(-80.0, 80.0, f), 0.0)

	# Цвет и яркость по времени суток.
	var col: Color
	if f < 0.5:
		col = Color(0.82, 0.88, 1.0).lerp(Color(1, 1, 1), clampf(f / 0.5, 0.0, 1.0))
	else:
		col = Color(1, 1, 1).lerp(Color(1.0, 0.5, 0.25), clampf((f - 0.5) / 0.4, 0.0, 1.0))
	light_energy = 0.15 + 1.0 * elev

	# Финал: красный закат «Баллады».
	if f >= GameConstants.PHASE_EVENING_END:
		var t := clampf((f - GameConstants.PHASE_EVENING_END) / (1.0 - GameConstants.PHASE_EVENING_END), 0.0, 1.0)
		col = Color(1.0, 0.5, 0.25).lerp(Color(0.7, 0.12, 0.1), t)
		light_energy = 0.10 + 0.25 * (1.0 - t)
	light_color = col

	if world_env and world_env.environment:
		world_env.environment.ambient_light_energy = 0.1 + 0.6 * elev
