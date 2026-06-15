extends Node
## Автолоад: вес игрока (DESIGN FROZEN, GDD §5). Старт 80 кг, диапазон 70–95.
##   • Скорость спуска: 70→×0.85, 80→×1.0, 90→×1.15, >90 — плато 1.15.
##   • Лок экстрима: ≥91 не пускают, пока не ≤90 (гистерезис).
##   • Набор: снек +1, блюдо +2. Сброс: туалет −3, бег −1 кг / 400 м.
##   • Река/ванны вес НЕ меняют (в воде add_run_distance не зовём).

var kg: float = GameConstants.WEIGHT_START
var _run_accum: float = 0.0          # накопленные метры бега к следующему −1 кг
var _extreme_locked: bool = false

func reset() -> void:
	kg = GameConstants.WEIGHT_START
	_run_accum = 0.0
	_extreme_locked = false
	EventBus.weight_changed.emit(Net.local_id(), kg)

# Множитель скорости спуска от веса.
func speed_factor() -> float:
	var w := clampf(kg, GameConstants.WEIGHT_MIN, GameConstants.WEIGHT_MAX)
	# 70→0.85 ... 90→1.15 линейно (0.015/кг), выше 90 — плато.
	return clampf(GameConstants.SPEED_AT_70 + (w - 70.0) * 0.015,
		GameConstants.SPEED_AT_70, GameConstants.SPEED_AT_90)

func can_ride_extreme() -> bool:
	return not _extreme_locked

func eat_snack() -> void:
	_set_kg(kg + GameConstants.SNACK_KG)

func eat_meal() -> void:
	_set_kg(kg + GameConstants.MEAL_KG)

func toilet() -> void:
	_set_kg(kg + GameConstants.TOILET_KG)   # TOILET_KG = −3

# Бег сжигает вес: каждые RUN_M_PER_KG метров → −1 кг.
func add_run_distance(meters: float) -> void:
	_run_accum += meters
	while _run_accum >= GameConstants.RUN_M_PER_KG:
		_run_accum -= GameConstants.RUN_M_PER_KG
		_set_kg(kg - 1.0)

# Прогресс к следующему сожжённому килограмму (0..1) — для HUD «сожжено X.X/1.0».
func burn_progress() -> float:
	return _run_accum / GameConstants.RUN_M_PER_KG

func _set_kg(v: float) -> void:
	kg = clampf(v, GameConstants.WEIGHT_MIN, GameConstants.WEIGHT_MAX)
	# Гистерезис лока экстрима: блок при ≥91, снятие при ≤90.
	if kg >= GameConstants.WEIGHT_LOCK:
		_extreme_locked = true
	elif kg <= GameConstants.WEIGHT_LOCK - 1.0:
		_extreme_locked = false
	EventBus.weight_changed.emit(Net.local_id(), kg)
