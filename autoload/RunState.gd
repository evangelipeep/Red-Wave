extends Node
## Автолоад: состояние забега для одного игрока (монеты, головокружение).
## Координирует «еду»: тратит монеты, меняет вес (WeightSystem) и голову.
## Позже станет server-authoritative (как Гул/квесты/вес).
## Головокружение растёт от горок (по тегу dizzy) и медленно спадает (GDD §6).

var coins: int = 0
var dizziness: int = 0
var current_zone: String = ""        # в какой зоне игрок ("" = центр/мост)
var main_quest: Array = []           # бандл атомов главного квеста (QuestGenerator)
var rides_total: int = 0             # сколько горок проехал (прокси-прогресс, фаза 1)
var dizziness_peak: int = 0          # пик головокружения за день (для финала)
var _dizzy_decay_accum: float = 0.0

const DIZZY_DECAY_EVERY := 6.0   # сек на −1 головокружения

func _ready() -> void:
	EventBus.slide_completed.connect(_on_slide_completed)

func reset() -> void:
	coins = GameConstants.COINS_START
	dizziness = 0
	current_zone = ""
	rides_total = 0
	dizziness_peak = 0
	EventBus.dizziness_changed.emit(Net.local_id(), dizziness)

func _process(delta: float) -> void:
	if dizziness <= 0:
		return
	_dizzy_decay_accum += delta
	if _dizzy_decay_accum >= DIZZY_DECAY_EVERY:
		_dizzy_decay_accum = 0.0
		add_dizziness(-1)

func add_dizziness(delta: int) -> void:
	dizziness = clampi(dizziness + delta, 0, GameConstants.DIZZY_MAX)
	dizziness_peak = maxi(dizziness_peak, dizziness)
	EventBus.dizziness_changed.emit(Net.local_id(), dizziness)

# Горка добавляет головокружение по своему тегу dizzy.
func _on_slide_completed(_player_id: int, slide_id: String) -> void:
	rides_total += 1
	var info: Dictionary = Slides.SLIDES.get(slide_id, {})
	add_dizziness(int(info.get("dizzy", 0)))

# Снек: +1 кг, −1 голова, 1 монета (GDD §5).
func try_eat_snack() -> bool:
	if coins < 1:
		return false
	coins -= 1
	WeightSystem.eat_snack()
	add_dizziness(-1)
	return true

# Блюдо: +2 кг, −3 голова, 2 монеты.
func try_eat_meal() -> bool:
	if coins < 2:
		return false
	coins -= 2
	WeightSystem.eat_meal()
	add_dizziness(-3)
	return true
