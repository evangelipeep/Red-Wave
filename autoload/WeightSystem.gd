extends Node
## Автолоад: вес игрока (GDD §5, балансовая правка v1.1).
##   • Старт 80 кг, диапазон 70–100. Набор — только едой (снек +1 / блюдо +2),
##     еда заодно снимает тошноту (RunState). Переел → лок экстрима.
##   • Скорость спуска: 70→×0.85, 80→×1.0, 90→×1.15, >90 — плато 1.15.
##   • Лок экстрима: ≥91 кг не пускают (тост), снятие при ≤90.
##   • Сброс: бег/прыжки сжигают калории (интенсивность важна), туалет −3 кг
##     но раз в 3 игровых часа (кулдаун). Плавание/река вес почти не меняют.

var kg: float = GameConstants.WEIGHT_START
var calories_burned: float = 0.0     # за забег (это игрок и будет видеть)
var _kg_accum: float = 0.0           # калории к следующему −1 кг
var _extreme_locked: bool = false
var _last_toilet_frac: float = -1.0  # доля дня последнего туалета (−1 = не ходил)

func reset() -> void:
	kg = GameConstants.WEIGHT_START
	calories_burned = 0.0
	_kg_accum = 0.0
	_extreme_locked = false
	_last_toilet_frac = -1.0
	EventBus.weight_changed.emit(Net.local_id(), kg)

# Множитель скорости спуска от веса.
func speed_factor() -> float:
	var w := clampf(kg, GameConstants.WEIGHT_MIN, GameConstants.WEIGHT_MAX)
	return clampf(GameConstants.SPEED_AT_70 + (w - 70.0) * 0.015,
		GameConstants.SPEED_AT_70, GameConstants.SPEED_AT_90)

func can_ride_extreme() -> bool:
	return not _extreme_locked

func eat_snack() -> void:
	_set_kg(kg + GameConstants.SNACK_KG)

func eat_meal() -> void:
	_set_kg(kg + GameConstants.MEAL_KG)

# --- Туалет с кулдауном (раз в 3 игровых часа). ---
func can_toilet() -> bool:
	return _last_toilet_frac < 0.0 \
		or (Clock.day_fraction - _last_toilet_frac) >= GameConstants.TOILET_COOLDOWN_FRAC

func toilet() -> bool:
	if not can_toilet():
		return false
	_last_toilet_frac = Clock.day_fraction
	_set_kg(kg + GameConstants.TOILET_KG)
	return true

# Сколько игровых часов осталось до доступности туалета (0 — готов).
func toilet_ready_in_hours() -> float:
	if can_toilet():
		return 0.0
	return (GameConstants.TOILET_COOLDOWN_FRAC - (Clock.day_fraction - _last_toilet_frac)) * 12.0

# --- Сжигание калорий (зовёт PlayerController по активности). ---
func burn(calories: float) -> void:
	if calories <= 0.0:
		return
	calories_burned += calories
	_kg_accum += calories
	while _kg_accum >= GameConstants.CAL_PER_KG:
		_kg_accum -= GameConstants.CAL_PER_KG
		_set_kg(kg - 1.0)

# Прогресс к следующему сожжённому килограмму (0..1).
func burn_progress() -> float:
	return _kg_accum / GameConstants.CAL_PER_KG

func _set_kg(v: float) -> void:
	kg = clampf(v, GameConstants.WEIGHT_MIN, GameConstants.WEIGHT_MAX)
	# Гистерезис лока: блок при ≥91, снятие при ≤90.
	if kg >= GameConstants.WEIGHT_LOCK:
		_extreme_locked = true
	elif kg <= GameConstants.WEIGHT_LOCK - 1.0:
		_extreme_locked = false
	EventBus.weight_changed.emit(Net.local_id(), kg)
