extends Node
## Автолоад: временные эффекты от еды (локальные для игрока — как голова/вес).
## Длительность — в ИГРОВЫХ минутах, переводится в долю дня (день = 12 игр.часов,
## ср. туалет: 3 ч = 0.25 дня). Таймеры чистятся по Clock.day_fraction.
##
## Эффекты лавок (см. data/food_menu.gd):
##   caffeine — скорость ×2 (кофейня)        heavy   — скорость ×0.8 (фастфуд, «тяжесть»)
##   hotsoup  — сжигание калорий ×1.5 (азия)  spicy   — следующий туалет без кулдауна (мексика)
##   light    — лёгкая еда (механика в kg блюда; таймера нет)

const GAME_HOURS_PER_DAY: float = 12.0
const SPEED_MULT := {"caffeine": 2.0, "heavy": 0.8}
const CAL_MULT := {"hotsoup": 1.5}

var _timed: Dictionary = {}      # effect_id -> доля дня, когда истекает
var _toilet_skip: bool = false   # «остро»: один туалет без кулдауна

func _ready() -> void:
	EventBus.run_started.connect(reset)
	EventBus.run_planning_started.connect(reset)

func reset() -> void:
	_timed.clear()
	_toilet_skip = false

# Применить эффект лавки. minutes>0 — таймер; spicy — разовый флаг; light — без эффекта тут.
func apply_effect(effect: String, minutes: float) -> void:
	match effect:
		"spicy":
			_toilet_skip = true
		"light":
			pass   # «лёгкость» уже заложена в малый kg блюда
		_:
			if minutes > 0.0:
				var frac: float = minutes / (GAME_HOURS_PER_DAY * 60.0)
				_timed[effect] = Clock.day_fraction + frac

func _process(_delta: float) -> void:
	if _timed.is_empty():
		return
	var t := Clock.day_fraction
	for k in _timed.keys():
		if float(_timed[k]) <= t:
			_timed.erase(k)

func is_active(effect: String) -> bool:
	return _timed.has(effect)

# Множитель скорости передвижения от активных эффектов (для PlayerController).
func move_speed_mult() -> float:
	var m := 1.0
	for e in _timed:
		m *= float(SPEED_MULT.get(e, 1.0))
	return m

# Множитель сжигания калорий (для WeightSystem.burn).
func calorie_mult() -> float:
	var m := 1.0
	for e in _timed:
		m *= float(CAL_MULT.get(e, 1.0))
	return m

# Разовый «без кулдауна туалета» (мексика). true — если был доступен и потрачен.
func consume_toilet_skip() -> bool:
	if _toilet_skip:
		_toilet_skip = false
		return true
	return false

# Для HUD: активные эффекты с остатком в игровых минутах (min<0 — разовый).
func active_list() -> Array:
	var r: Array = []
	var t := Clock.day_fraction
	for e in _timed:
		var mins: float = (float(_timed[e]) - t) * GAME_HOURS_PER_DAY * 60.0
		r.append({"id": e, "min": maxf(mins, 0.0)})
	if _toilet_skip:
		r.append({"id": "spicy", "min": -1.0})
	return r
