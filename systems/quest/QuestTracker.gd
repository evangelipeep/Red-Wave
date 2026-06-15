extends Node
## Автолоад: трекинг главного квеста. По ходу дня проверяет каждый атом бандла
## (RunState.main_quest), считает выполнение и начисляет MAIN_PAYOUT при полном
## завершении. Оценивает то, что уже есть в игре (горки, вес, голова, еда по зонам);
## атомы систем «в разработке» (театры/лавки/гонки/очереди/круги) пока авто-зачёт.

const AUTO_AXES := ["shows", "bard", "shop", "race", "skip", "laps"]
const EVE_19_FRAC := 10.0 / 12.0   # 19:00 при дне 09:00–21:00

var done: Array = []        # done[i] для main_quest[i]
var _paid: bool = false

# Сырой трекинг за день.
var _ride_counts: Dictionary = {}
var _eaten_zones: Dictionary = {}
var _saw_dizzy_max: bool = false
var _dizzy_cleared_in_time: bool = false
var _weighthi_done: bool = false

func _ready() -> void:
	EventBus.run_started.connect(_on_run_started)
	EventBus.slide_completed.connect(_on_ride)
	EventBus.food_eaten.connect(_on_food)
	EventBus.dizziness_changed.connect(_on_dizzy)
	Clock.day_finished.connect(_on_day_finished)

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
	_paid = false
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
