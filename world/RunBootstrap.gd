extends Node3D
## Запуск забега в тестовой сцене: бросает Гул, сбрасывает вес/монеты,
## запускает часы дня. Позже это возьмёт на себя лобби/сервер (фаза 3).

@export var debug_run_length: float = 120.0   # короткий день для теста (реальные сек); боевое — 1800
@export var use_planning: bool = true          # фаза планирования (ParkGreybox); тест горки — false

const BALLAD_RADIUS := 13.0   # «красный круг» в центре — куда надо прийти к финалу

var _ballad_started: bool = false
var _ballad_attended: bool = false

func _ready() -> void:
	GameConstants.run_length = debug_run_length
	WeightSystem.reset()
	RunState.reset()
	RunState.coins = 30   # DEBUG: больше монет, чтобы можно было переесть до лока ≥91 кг
	Hype.roll()
	RunState.main_quest = QuestGenerator.generate_main()
	RunState.personal_quest = QuestGenerator.generate_personal()
	print("[Run] горка дня = %s, день = %.0f сек, атомов в квесте = %d" % [
		Hype.day_slide, debug_run_length, RunState.main_quest.size()])
	EventBus.scheduled_event.connect(_on_scheduled)
	Clock.day_finished.connect(_on_day_end)
	if use_planning:
		EventBus.run_planning_started.emit()   # старт дня запускает PlanningOverlay
	else:
		Clock.start_run()
		EventBus.run_started.emit()

func _on_scheduled(ev: String) -> void:
	if ev == "ballad":
		_ballad_started = true
		EventBus.toast.emit("Баллада начинается — идите в центр (красный круг)!")

func _process(_delta: float) -> void:
	if not _ballad_started or _ballad_attended:
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var p := players[0] as Node3D
	if Vector2(p.global_position.x, p.global_position.z).length() < BALLAD_RADIUS:
		_ballad_attended = true

func _on_day_end() -> void:
	# Штраф только в настоящем парке (где есть зоны), не в тест-сцене горки.
	if get_tree().get_nodes_in_group("zone").is_empty():
		return
	if _ballad_started and not _ballad_attended:
		RunState.add_score(GameConstants.MISS_BALLAD)
		EventBus.toast.emit("Пропустил Балладу! %d очка" % GameConstants.MISS_BALLAD)
