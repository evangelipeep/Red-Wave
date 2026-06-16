extends Node
## Автолоад: состояние забега для одного игрока (монеты, головокружение).
## Координирует «еду»: тратит монеты, меняет вес (WeightSystem) и голову.
## Позже станет server-authoritative (как Гул/квесты/вес).
## Головокружение растёт от горок (по тегу dizzy) и медленно спадает (GDD §6).

var coins: int = 0
var dizziness: int = 0
var current_zone: String = ""        # в какой зоне игрок ("" = центр/мост)
var main_quest: Array = []           # бандл атомов главного квеста (QuestGenerator)
var personal_quest: Array = []       # личное доп-задание (1 атом)
var rides_total: int = 0             # сколько горок проехал (прокси-прогресс, фаза 1)
var dizziness_peak: int = 0          # пик головокружения за день (для финала)
var score: int = 0                   # очки за день
var markers: Array[Vector3] = []     # приватные метки игрока (карта M)
var pings: Array = []                # активные пинги [{pos, until}] для карты/миникарты
var souvenirs: Dictionary = {}       # купленные сувениры по лавкам (shop_id → true)
var bard_photo: bool = false         # сделал фото с Бардом
var offenses: int = 0                 # нарушений очереди (прыжки без очереди)
var run_blocked: bool = false         # бег заблокирован охраной (наказание)
var queue_jump_banned: bool = false   # после 2 нарушений — прыгать без очереди вообще нельзя
var _legit_rides_since_block: int = 0
var _zones_visited: Dictionary = {}  # для бонуса «первопроходец зоны»
var _dizzy_decay_accum: float = 0.0

const DIZZY_DECAY_EVERY := 6.0   # сек на −1 головокружения

func _ready() -> void:
	EventBus.slide_completed.connect(_on_slide_completed)
	EventBus.ping_made.connect(_on_ping_made)

func _on_ping_made(_player_id: int, world_pos: Vector3, _context: String) -> void:
	pings.append({"pos": world_pos, "until": Time.get_ticks_msec() / 1000.0 + GameConstants.PING_LIFE})

func reset() -> void:
	coins = GameConstants.COINS_START
	dizziness = 0
	current_zone = ""
	rides_total = 0
	dizziness_peak = 0
	score = 0
	markers.clear()
	pings.clear()
	souvenirs.clear()
	bard_photo = false
	personal_quest.clear()
	offenses = 0
	run_blocked = false
	queue_jump_banned = false
	_legit_rides_since_block = 0
	_zones_visited.clear()
	EventBus.dizziness_changed.emit(Net.local_id(), dizziness)
	EventBus.score_changed.emit(Net.local_id(), score)

func add_score(delta: int) -> void:
	score += delta
	EventBus.score_changed.emit(Net.local_id(), score)

# Прыжок без очереди пойман: штраф, блок бега, реакция охраны.
func register_offense() -> void:
	offenses += 1
	add_score(GameConstants.SHAME)
	run_blocked = true
	_legit_rides_since_block = 0
	if offenses >= GameConstants.HOOLIGAN_BAN_AFTER:
		queue_jump_banned = true
	EventBus.run_block_changed.emit(true)
	EventBus.guard_alert.emit(offenses)
	EventBus.toast.emit("Неуважение к очереди! %d очков. Бег заблокирован — отстойте %d очереди." % [
		GameConstants.SHAME, GameConstants.QUEUES_TO_RESTORE_RUN])

# Честно отстоял очередь и прокатился — шаг к снятию блокировки бега.
func register_legit_ride() -> void:
	if not run_blocked:
		return
	_legit_rides_since_block += 1
	if _legit_rides_since_block >= GameConstants.QUEUES_TO_RESTORE_RUN:
		run_blocked = false
		EventBus.run_block_changed.emit(false)
		EventBus.toast.emit("Вы исправились — бег снова доступен!")
	else:
		EventBus.toast.emit("Очередь отстояна честно (%d/%d)" % [
			_legit_rides_since_block, GameConstants.QUEUES_TO_RESTORE_RUN])

# --- Приватные метки (карта M). ---
func add_marker(pos: Vector3) -> void:
	pos.y = 0.0
	markers.append(pos)
	if markers.size() > 6:
		markers.pop_front()

func remove_marker_near(pos: Vector3) -> void:
	var best_i := -1
	var best_d := 8.0
	for i in markers.size():
		var d := Vector2(markers[i].x - pos.x, markers[i].z - pos.z).length()
		if d < best_d:
			best_d = d
			best_i = i
	if best_i >= 0:
		markers.remove_at(best_i)

# Первый визит в зону за день → бонус «первопроходец».
func visit_zone(zone: String) -> void:
	if zone == "" or _zones_visited.has(zone):
		return
	_zones_visited[zone] = true
	add_score(GameConstants.ZONE_FIRST)
	EventBus.toast.emit("Первопроходец зоны! +%d очков" % GameConstants.ZONE_FIRST)

func _process(delta: float) -> void:
	# Чистим протухшие пинги.
	if not pings.is_empty():
		var t := Time.get_ticks_msec() / 1000.0
		for i in range(pings.size() - 1, -1, -1):
			if float(pings[i]["until"]) <= t:
				pings.remove_at(i)
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
	EventBus.food_eaten.emit(current_zone)
	return true

# Блюдо: +2 кг, −3 голова, 2 монеты.
func try_eat_meal() -> bool:
	if coins < 2:
		return false
	coins -= 2
	WeightSystem.eat_meal()
	add_dizziness(-3)
	EventBus.food_eaten.emit(current_zone)
	return true
