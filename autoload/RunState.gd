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
var river_laps: int = 0              # кругов по ленивой реке
var fast_passes: int = 0            # пропуска «без очереди»
var skips_used: int = 0             # сколько раз прошёл без очереди по пропуску
var race_wins: int = 0              # побед в гонках (Рой)
var offenses: int = 0                 # нарушений очереди (прыжки без очереди)
var run_blocked: bool = false         # бег заблокирован охраной (наказание)
var queue_jump_banned: bool = false   # после 2 нарушений — прыгать без очереди вообще нельзя

# --- Фуд-корт (этап 1) ---
var in_food_court: bool = false       # игрок внутри зоны фуд-корта (FoodCourtZone)
var pending_orders: Array = []        # выданные пищалки {stall_id, color, ready_at, dishes:[]}
var trays: Array = []                 # забранные подносы (≤4) {stall_id, color, dishes:[]}
var selected_slot: int = -1           # активный слот подноса (для еды/рук/выброса)

const MAX_TRAYS := 4

# --- Предметы ---
var pills: int = 0                    # таблетки от тошноты
var has_gun: bool = false             # куплен пистолет-отталкиватель

# --- Раздевалка ---
var locker_number: int = 0            # личный шкафчик игрока (выдаётся случайно)
var side_quests: Array = []           # доп.желания с ресепшна (атомы; за провал штраф)

# --- Финал ---
var finale_attended: bool = false     # был в театре на финальном представлении (итоги)
var _legit_rides_since_block: int = 0
var _zones_visited: Dictionary = {}  # для бонуса «первопроходец зоны»
var _dizzy_decay_accum: float = 0.0

const DIZZY_DECAY_EVERY := 9.0   # сек на −1 тошноты (медленно; основное лечение — спа/еда/театр)

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
	river_laps = 0
	fast_passes = 0
	skips_used = 0
	race_wins = 0
	personal_quest.clear()
	offenses = 0
	run_blocked = false
	queue_jump_banned = false
	in_food_court = false
	pending_orders.clear()
	trays.clear()
	selected_slot = -1
	pills = 0
	has_gun = false
	locker_number = 0
	side_quests.clear()
	finale_attended = false
	_legit_rides_since_block = 0
	_zones_visited.clear()
	EventBus.dizziness_changed.emit(Net.local_id(), dizziness)
	EventBus.score_changed.emit(Net.local_id(), score)

func add_score(delta: int) -> void:
	score += delta
	EventBus.score_changed.emit(Net.local_id(), score)

# Случайный личный шкафчик (показываем на приветственном экране и у шкафчиков).
func assign_locker() -> void:
	locker_number = randi_range(1, 200)

func add_lap() -> void:
	river_laps += 1
	EventBus.toast.emit("Круг по реке! (%d)" % river_laps)

func add_race_win() -> void:
	race_wins += 1
	add_score(GameConstants.RACE_WIN)
	EventBus.toast.emit("Победа в гонке! +%d (всего %d)" % [GameConstants.RACE_WIN, race_wins])

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

# Слишком укачало — на горки не пускают (нужно отдохнуть).
func is_too_sick() -> bool:
	return dizziness >= GameConstants.DIZZY_MAX

func add_dizziness(delta: int) -> void:
	var prev := dizziness
	dizziness = clampi(dizziness + delta, 0, GameConstants.DIZZY_MAX)
	dizziness_peak = maxi(dizziness_peak, dizziness)
	if delta > 0:
		if dizziness >= GameConstants.DIZZY_MAX and prev < GameConstants.DIZZY_MAX:
			EventBus.toast.emit("🤢 Тебя сильно укачало! Кататься нельзя — отдохни в спа (онсен/джакузи/сауна), поешь или сходи в театр.")
		elif dizziness >= GameConstants.NAUSEA_WARN and prev < GameConstants.NAUSEA_WARN:
			EventBus.toast.emit("Подташнивает… скоро не сможешь кататься. Стоит отдохнуть или поесть.")
	EventBus.dizziness_changed.emit(Net.local_id(), dizziness)

# Горка гарантированно укачивает: база + тег dizzy горки.
func _on_slide_completed(_player_id: int, slide_id: String) -> void:
	rides_total += 1
	var info: Dictionary = Slides.SLIDES.get(slide_id, {})
	add_dizziness(GameConstants.NAUSEA_RIDE_BASE + int(info.get("dizzy", 0)))

# =========================================================================
#  Фуд-корт: заказы (пищалки) → подносы (инвентарь ≤4) → еда в зоне (этап 1).
#  Логику лавок/очереди/готовки добавит StallPOI (этап 3); тут — данные и правила.
# =========================================================================

func can_take_tray() -> bool:
	return trays.size() < MAX_TRAYS

# Есть ли уже выданная пищалка (заказ) этой лавки.
func has_pending(stall_id: String) -> bool:
	for o in pending_orders:
		if o["stall_id"] == stall_id:
			return true
	return false

# Оформлен заказ в лавке: выдаём пищалку. ready_at — доля дня готовности.
func add_pending_order(stall_id: String, ready_at: float, dishes: Array) -> void:
	pending_orders.append({
		"stall_id": stall_id,
		"color": FoodMenu.stall_color(stall_id),
		"ready_at": ready_at,
		"dishes": dishes.duplicate(true),
	})
	EventBus.toast.emit("Заказ принят (%s) — ждите пищалку." % FoodMenu.stall_name(stall_id))

func order_is_ready(order: Dictionary) -> bool:
	return Clock.day_fraction >= float(order.get("ready_at", 1.0))

# Есть ли готовый, но не забранный заказ этой лавки.
func has_ready_order(stall_id: String) -> bool:
	for o in pending_orders:
		if o["stall_id"] == stall_id and order_is_ready(o):
			return true
	return false

# Забрать готовый заказ лавки в поднос (в зоне выдачи). false — нет места/нет готового.
func collect_order(stall_id: String) -> bool:
	for i in pending_orders.size():
		var o: Dictionary = pending_orders[i]
		if o["stall_id"] != stall_id or not order_is_ready(o):
			continue
		if not can_take_tray():
			EventBus.toast.emit("Нет места в инвентаре — доешьте или выбросите поднос.")
			return false
		trays.append({"stall_id": stall_id, "color": o["color"], "dishes": o["dishes"]})
		pending_orders.remove_at(i)
		if selected_slot < 0:
			selected_slot = trays.size() - 1
		EventBus.toast.emit("Поднос получен: %s" % FoodMenu.stall_name(stall_id))
		return true
	return false

# =========================================================================
#  Хотбар (быстрый доступ): единый список снаряжения, по которому ходит
#  selected_slot — сначала подносы (≤4), затем таблетки (если есть), затем
#  пистолет (если куплен). Цифры 1-4 и колесо мыши переключают по нему.
#  Важно: индекс подноса в trays совпадает с индексом слота в хотбаре, пока
#  это слот подноса (подносы идут первыми) — на это опираются eat/drop/trash.
# =========================================================================
func hotbar() -> Array:
	var h: Array = []
	for t in trays:
		h.append({"kind": "tray", "tray": t})
	if pills > 0:
		h.append({"kind": "pill", "qty": pills})
	if has_gun:
		h.append({"kind": "gun"})
	return h

func hotbar_size() -> int:
	return trays.size() + (1 if pills > 0 else 0) + (1 if has_gun else 0)

# Что в активном слоте: {} | {kind:"tray",tray:..} | {kind:"pill",qty:..} | {kind:"gun"}
func active_slot() -> Dictionary:
	var h := hotbar()
	if selected_slot >= 0 and selected_slot < h.size():
		return h[selected_slot]
	return {}

func select_slot(i: int) -> void:
	if i >= 0 and i < hotbar_size():
		selected_slot = i

# Переключить активный слот колесом мыши (dir = -1/+1) по всему снаряжению, по кругу.
func cycle_slot(dir: int) -> void:
	var n := hotbar_size()
	if n == 0:
		return
	var start := selected_slot if selected_slot >= 0 else 0
	selected_slot = (start + dir + n) % n

# Положить поднос в инвентарь (подбор выброшенной еды). false — нет места.
func add_tray(tray: Dictionary) -> bool:
	if not can_take_tray():
		return false
	trays.append(tray)
	if selected_slot < 0:
		selected_slot = trays.size() - 1
	return true

# Съесть одно блюдо из подноса (только в зоне фуд-корта). Опустевший поднос убираем.
func eat_from_slot(i: int) -> bool:
	if i < 0 or i >= trays.size():
		return false
	if not in_food_court:
		EventBus.toast.emit("Есть можно только на фуд-корте.")
		return false
	var tray: Dictionary = trays[i]
	var tray_dishes: Array = tray["dishes"]
	if tray_dishes.is_empty():
		return false
	var dish: Dictionary = tray_dishes.pop_back()
	var stall_id: String = tray["stall_id"]
	WeightSystem.eat(float(dish.get("kg", 1.0)))
	add_dizziness(int(dish.get("dizzy", 0)))
	var stall: Dictionary = FoodMenu.stall(stall_id)
	PlayerBuffs.apply_effect(str(stall.get("effect", "")), float(stall.get("effect_min", 0.0)))
	EventBus.food_eaten.emit(stall_id)
	EventBus.toast.emit("Съедено: %s" % str(dish.get("name", "блюдо")))
	if tray_dishes.is_empty():
		trays.remove_at(i)
		_fix_selected()
	return true

# Выбросить поднос на землю (другой игрок сможет подобрать). Возвращает данные подноса.
func drop_tray(i: int) -> Dictionary:
	if i < 0 or i >= trays.size():
		return {}
	var tray: Dictionary = trays[i]
	trays.remove_at(i)
	_fix_selected()
	return tray

# Выбросить поднос в мусорку (уничтожить).
func trash_tray(i: int) -> void:
	if i < 0 or i >= trays.size():
		return
	trays.remove_at(i)
	_fix_selected()

func _fix_selected() -> void:
	var n := hotbar_size()
	if n == 0:
		selected_slot = -1
	else:
		selected_slot = clampi(selected_slot, 0, n - 1)

# --- Предметы: таблетки и пистолет (магазин ItemShopPOI). ---
func buy_pill() -> bool:
	if coins < GameConstants.PILL_COST:
		EventBus.toast.emit("Не хватает монет на таблетку (нужно %d)." % GameConstants.PILL_COST)
		return false
	coins -= GameConstants.PILL_COST
	pills += 1
	if selected_slot < 0:
		selected_slot = hotbar_size() - 1   # авто-выбор первого появившегося предмета
	EventBus.toast.emit("Куплена таблетка от тошноты (всего %d)." % pills)
	return true

func buy_gun() -> bool:
	if has_gun:
		EventBus.toast.emit("Пистолет уже куплен.")
		return false
	if coins < GameConstants.GUN_COST:
		EventBus.toast.emit("Не хватает монет на пистолет (нужно %d)." % GameConstants.GUN_COST)
		return false
	coins -= GameConstants.GUN_COST
	has_gun = true
	if selected_slot < 0:
		selected_slot = hotbar_size() - 1
	EventBus.toast.emit("Куплен пистолет-отталкиватель! ПКМ — толкать.")
	return true

func use_pill() -> bool:
	if pills <= 0:
		EventBus.toast.emit("Нет таблеток от тошноты.")
		return false
	pills -= 1
	_fix_selected()                          # таблетки кончились → слот исчезает, выбор сдвигаем
	dizziness = 0
	dizziness_peak = maxi(dizziness_peak, 0)
	EventBus.dizziness_changed.emit(Net.local_id(), 0)
	EventBus.toast.emit("Таблетка: тошнота снята! (таблеток: %d)" % pills)
	return true
