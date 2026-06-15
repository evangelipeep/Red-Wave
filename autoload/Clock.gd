extends Node
## Автолоад: часы дня. Двигает day_fraction 0→1 за run_length реальных секунд.
## Разделяет МИРОВОЕ время (масштабируется длиной забега) и РЕАКЦИОННОЕ (реальные сек),
## чтобы окна QTE/буферы не становились нечестными на коротких забегах (баг #4).

signal phase_changed(phase: String)
signal scheduled_event(event: String)
signal day_finished()

var day_fraction: float = 0.0
var running: bool = false
var _phase: String = "planning"
var _fired: Dictionary = {}   # какие события расписания уже сработали

# Точки расписания: доля дня -> имя события (EventBus)
var _schedule: Array = []

func _ready() -> void:
	_build_schedule()

func _build_schedule() -> void:
	_schedule.clear()
	_schedule.append([GameConstants.SHOW_SLOTS[0], "show_1"])
	_schedule.append([GameConstants.PARADE, "parade"])
	_schedule.append([GameConstants.SHOW_SLOTS[1], "show_2"])
	_schedule.append([GameConstants.MAINT, "maintenance"])
	_schedule.append([GameConstants.SHOW_SLOTS[2], "show_3"])
	_schedule.append([GameConstants.DESK_CLOSE, "desk_close"])
	_schedule.append([GameConstants.BALLAD, "ballad"])

func start_run() -> void:
	day_fraction = 0.0
	_fired.clear()
	running = true
	_set_phase("morning")

func _process(delta: float) -> void:
	if not running:
		return
	# МИРОВОЕ время: за run_length реальных секунд проходит весь день (доля 0→1)
	day_fraction += delta / GameConstants.run_length
	day_fraction = min(day_fraction, 1.0)
	_check_phase()
	_check_schedule()
	if day_fraction >= 1.0:
		running = false
		day_finished.emit()

func _check_phase() -> void:
	var p := "morning"
	if day_fraction >= GameConstants.PHASE_EVENING_END:
		p = "finale"
	elif day_fraction >= GameConstants.PHASE_NOON_END:
		p = "evening"
	elif day_fraction >= GameConstants.PHASE_MORNING_END:
		p = "noon"
	if p != _phase:
		_set_phase(p)

func _set_phase(p: String) -> void:
	_phase = p
	phase_changed.emit(p)
	if EventBus:
		EventBus.phase_changed.emit(p)

func _check_schedule() -> void:
	for item in _schedule:
		var frac: float = item[0]
		var ev_name: String = item[1]
		if day_fraction >= frac and not _fired.has(ev_name):
			_fired[ev_name] = true
			scheduled_event.emit(ev_name)
			if EventBus:
				EventBus.scheduled_event.emit(ev_name)

# Текущее игровое время как строка "ЧЧ:ММ" (09:00–21:00)
func game_time_string() -> String:
	var minutes_total := int(day_fraction * 12.0 * 60.0)  # 12 часов дня
	@warning_ignore("integer_division")
	var h := 9 + minutes_total / 60
	var m := minutes_total % 60
	return "%02d:%02d" % [h, m]

func phase() -> String:
	return _phase

# Множитель очереди по фазе (утро 0, вечер 0.35, полдень 1.0)
func queue_phase_multiplier() -> float:
	match _phase:
		"morning": return 0.0
		"evening": return 0.35
		"finale": return 0.0
		_: return 1.0
