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
var weight_min: float = GameConstants.WEIGHT_START  # рекорды дня (для финала)
var weight_max: float = GameConstants.WEIGHT_START
var _kg_accum: float = 0.0           # калории к следующему −1 кг
var _extreme_locked: bool = false
var _last_toilet_frac: float = -1.0  # доля дня последнего туалета (−1 = не ходил)

func reset() -> void:
	kg = GameConstants.WEIGHT_START
	calories_burned = 0.0
	weight_min = GameConstants.WEIGHT_START
	weight_max = GameConstants.WEIGHT_START
	_kg_accum = 0.0
	_extreme_locked = false
	_last_toilet_frac = -1.0
	EventBus.weight_changed.emit(Net.local_id(), kg)

# Множитель скорости спуска от веса: 70→0.85, 90→1.15, 100→1.30 (тяжелее = быстрее/мощнее).
func speed_factor() -> float:
	var w := clampf(kg, GameConstants.WEIGHT_MIN, GameConstants.WEIGHT_MAX)
	return clampf(GameConstants.SPEED_AT_70 + (w - 70.0) * 0.015,
		GameConstants.SPEED_AT_70, GameConstants.SPEED_AT_100)

func can_ride_extreme() -> bool:
	return not _extreme_locked

# «Толстый» (≥90 кг): меняется походка/скорость/модель, часть экстрима под запретом.
func is_heavy() -> bool:
	return kg >= GameConstants.HEAVY_KG

# 0 при ≤90 кг → 1 при 100 кг (плавная сила эффектов походки/камеры/модели).
func heavy01() -> float:
	return clampf((kg - GameConstants.HEAVY_KG) / (GameConstants.WEIGHT_MAX - GameConstants.HEAVY_KG), 0.0, 1.0)

# Пеший множитель скорости: 1.0 до 90 кг, плавно до HEAVY_MOVE_FACTOR к 100 кг.
func move_factor() -> float:
	return lerpf(1.0, GameConstants.HEAVY_MOVE_FACTOR, heavy01())

# Съесть блюдо: добавить его вес (kg задаётся блюдом в data/food_menu.gd).
func eat(kg_amount: float) -> void:
	_set_kg(kg + kg_amount)

# --- Туалет с кулдауном (раз в 3 игровых часа). ---
func can_toilet() -> bool:
	return _last_toilet_frac < 0.0 \
		or (Clock.day_fraction - _last_toilet_frac) >= GameConstants.TOILET_COOLDOWN_FRAC

func toilet() -> bool:
	# «Остро» (мексика) — один поход без кулдауна.
	if not can_toilet() and not PlayerBuffs.consume_toilet_skip():
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
	calories *= PlayerBuffs.calorie_mult()   # «горячий суп» (азия) ускоряет сжигание
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
	weight_min = minf(weight_min, kg)
	weight_max = maxf(weight_max, kg)
	# Гистерезис лока: блок при ≥91, снятие при ≤90.
	if kg >= GameConstants.WEIGHT_LOCK:
		_extreme_locked = true
	elif kg <= GameConstants.WEIGHT_LOCK - 1.0:
		_extreme_locked = false
	EventBus.weight_changed.emit(Net.local_id(), kg)
