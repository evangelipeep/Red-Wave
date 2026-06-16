extends Node
## Автолоад: трекинг главного квеста. По ходу дня проверяет каждый атом бандла
## (RunState.main_quest), считает выполнение и начисляет MAIN_PAYOUT при полном
## завершении. Оценивает то, что уже есть (горки, вес, голова, еда, театры/шоу);
## атомы систем «в разработке» (лавки/гонки/очереди/круги) пока авто-зачёт.

const AUTO_AXES := ["race", "skip", "laps"]
const EVE_19_FRAC := 10.0 / 12.0   # 19:00 при дне 09:00–21:00
const SHOW_WINDOW := 20.0          # сек, сколько идёт шоу после старта

var done: Array = []        # done[i] для main_quest[i]
var _paid: bool = false
var personal_done: bool = false
var _personal_paid: bool = false

# Сырой трекинг за день.
var _ride_counts: Dictionary = {}
var _eaten_zones: Dictionary = {}
var _saw_dizzy_max: bool = false
var _dizzy_cleared_in_time: bool = false
var _weighthi_done: bool = false
var _shows_attended: int = 0
var _show_window: float = 0.0
var _show_counted: bool = false

func _ready() -> void:
	EventBus.run_started.connect(_on_run_started)
	EventBus.slide_completed.connect(_on_ride)
	EventBus.food_eaten.connect(_on_food)
	EventBus.dizziness_changed.connect(_on_dizzy)
	EventBus.scheduled_event.connect(_on_scheduled)
	Clock.day_finished.connect(_on_day_finished)

func _process(delta: float) -> void:
	if _show_window <= 0.0:
		return
	_show_window -= delta
	if not _show_counted and _at_theater():
		_show_counted = true
		_shows_attended += 1
		EventBus.toast.emit("Посетил шоу! (%d)" % _shows_attended)
		_reevaluate(true)

func _on_scheduled(ev: String) -> void:
	if ev.begins_with("show"):
		_show_window = SHOW_WINDOW
		_show_counted = false

func _at_theater() -> bool:
	for t in get_tree().get_nodes_in_group("poi_theater"):
		if (t as TheaterPOI).player_inside:
			return true
	return false

func is_done(i: int) -> bool:
	return i >= 0 and i < done.size() and done[i]

func quest_complete() -> bool:
	if done.is_empty():
		return false
	for d in done:
		if not d:
			return false
	return true

func _on_run_started() -> void:
	_ride_counts.clear()
	_eaten_zones.clear()
	_saw_dizzy_max = false
	_dizzy_cleared_in_time = false
	_weighthi_done = false
	_shows_attended = 0
	_show_window = 0.0
	_show_counted = false
	_paid = false
	personal_done = false
	_personal_paid = false
	done.clear()
	done.resize(RunState.main_quest.size())
	for i in done.size():
		done[i] = false
	_reevaluate(false)

func _on_ride(_pid: int, slide_id: String) -> void:
	_ride_counts[slide_id] = int(_ride_counts.get(slide_id, 0)) + 1
	var info: Dictionary = Slides.SLIDES.get(slide_id, {})
	if info.get("extreme", false) and WeightSystem.kg >= 88.0 and WeightSystem.kg <= 90.0:
		_weighthi_done = true
	_reevaluate(true)

func _on_food(zone: String) -> void:
	if zone != "":
		_eaten_zones[zone] = true
	_reevaluate(true)

func _on_dizzy(_pid: int, level: int) -> void:
	if level >= GameConstants.DIZZY_MAX:
		_saw_dizzy_max = true
	if _saw_dizzy_max and level == 0 and Clock.day_fraction < EVE_19_FRAC:
		_dizzy_cleared_in_time = true
	_reevaluate(true)

func _on_day_finished() -> void:
	_reevaluate(true)   # финальные атомы (вес на финише)

func _reevaluate(can_pay: bool) -> void:
	if RunState.main_quest.is_empty():
		return
	if done.size() != RunState.main_quest.size():
		done.resize(RunState.main_quest.size())
	var all_done := true
	for i in RunState.main_quest.size():
		var atom: Dictionary = RunState.main_quest[i]
		var d := _evaluate(atom)
		if d and not done[i]:
			EventBus.quest_progress.emit(Net.local_id(), str(atom.get("name", "")), true)
		done[i] = d
		if not d:
			all_done = false
	if all_done and can_pay and not _paid:
		_paid = true
		RunState.add_score(GameConstants.MAIN_PAYOUT)
		EventBus.toast.emit("Главный квест выполнен! +%d очков" % GameConstants.MAIN_PAYOUT)

	# Личное доп-задание.
	if not RunState.personal_quest.is_empty():
		var pd := _evaluate(RunState.personal_quest[0])
		if pd and not personal_done:
			EventBus.quest_progress.emit(Net.local_id(), str(RunState.personal_quest[0].get("name", "")), true)
		personal_done = pd
		if pd and can_pay and not _personal_paid:
			_personal_paid = true
			RunState.add_score(GameConstants.PERSONAL_PTS)
			EventBus.toast.emit("Личное задание выполнено! +%d очков" % GameConstants.PERSONAL_PTS)

# Прогресс атома главного квеста (текущее, нужно) — для карточек «2/5».
func progress(i: int) -> Vector2i:
	if i < 0 or i >= RunState.main_quest.size():
		return Vector2i(0, 1)
	return _progress_atom(RunState.main_quest[i])

func personal_progress() -> Vector2i:
	if RunState.personal_quest.is_empty():
		return Vector2i(0, 1)
	return _progress_atom(RunState.personal_quest[0])

func personal_is_done() -> bool:
	return personal_done

func _progress_atom(a: Dictionary) -> Vector2i:
	var axis := str(a.get("axis", ""))
	var n := int(a.get("n", 1))
	match axis:
		"extreme":
			return Vector2i(mini(_count(func(id): return Slides.SLIDES[id].get("extreme", false)), n), n)
		"calm":
			return Vector2i(mini(_count(func(id): return Slides.SLIDES[id].get("calm", false)), n), n)
		"sens":
			var s := str(a.get("sensation", ""))
			return Vector2i(mini(_count(func(id): return Slides.SLIDES[id].get("sensation", "") == s), n), n)
		"temp":
			var t := str(a.get("temp", ""))
			return Vector2i(mini(_count(func(id): return Slides.SLIDES[id].get("temp", "") == t), n), n)
		"gul":
			return Vector2i(mini(_count(func(id): return int(Hype.gul.get(id, 50)) < 50), n), n)
		"perzone":
			return Vector2i(_zones_ridden(), Slides.ZONES.size())
		"diffsens":
			return Vector2i(mini(_distinct_sensations(), n), n)
		"closezone":
			var z := str(a.get("zone", ""))
			return Vector2i(_zone_ridden_count(z), Slides.in_zone(z).size())
		"food":
			return Vector2i(mini(_eaten_zones.size(), 3), 3)
		"shop":
			return Vector2i(mini(RunState.souvenirs.size(), 3), 3)
		"shows":
			return Vector2i(mini(_shows_attended, n), n)
		_:
			return Vector2i(1 if _evaluate(a) else 0, 1)

func _zone_ridden_count(zone: String) -> int:
	var c := 0
	for id in Slides.in_zone(zone):
		if _ride_counts.has(id):
			c += 1
	return c

func _evaluate(atom: Dictionary) -> bool:
	var axis := str(atom.get("axis", ""))
	if axis in AUTO_AXES:
		return true   # система в разработке — авто-зачёт
	var n := int(atom.get("n", 1))
	match axis:
		"extreme":
			return _count(func(id): return Slides.SLIDES[id].get("extreme", false)) >= n
		"calm":
			return _count(func(id): return Slides.SLIDES[id].get("calm", false)) >= n
		"sens":
			var s := str(atom.get("sensation", ""))
			return _count(func(id): return Slides.SLIDES[id].get("sensation", "") == s) >= n
		"temp":
			var t := str(atom.get("temp", ""))
			return _count(func(id): return Slides.SLIDES[id].get("temp", "") == t) >= n
		"gul":
			return _count(func(id): return int(Hype.gul.get(id, 50)) < 50) >= n
		"perzone":
			return _zones_ridden() >= Slides.ZONES.size()
		"closezone":
			var z := str(atom.get("zone", ""))
			return _zone_closed(z)
		"diffsens":
			return _distinct_sensations() >= n
		"food":
			return _eaten_zones.size() >= 3
		"shop":
			return RunState.souvenirs.size() >= 3
		"bard":
			return RunState.bard_photo
		"shows":
			return _shows_attended >= n
		"weightlow":
			return (not Clock.running) and WeightSystem.kg <= 79.0
		"weighthi":
			return _weighthi_done
		"dizzy":
			return _dizzy_cleared_in_time
		_:
			return true

# --- Запросы по проеханным горкам. ---
func _count(pred: Callable) -> int:
	var c := 0
	for id in _ride_counts:
		if pred.call(id):
			c += 1
	return c

func _zones_ridden() -> int:
	var zones := {}
	for id in _ride_counts:
		zones[Slides.SLIDES[id].get("zone", "")] = true
	return zones.size()

func _zone_closed(zone: String) -> bool:
	for id in Slides.in_zone(zone):
		if not _ride_counts.has(id):
			return false
	return true

func _distinct_sensations() -> int:
	var s := {}
	for id in _ride_counts:
		s[Slides.SLIDES[id].get("sensation", "")] = true
	return s.size()
