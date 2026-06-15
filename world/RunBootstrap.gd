extends Node3D
## Запуск забега в тестовой сцене: бросает Гул, сбрасывает вес/монеты,
## запускает часы дня. Позже это возьмёт на себя лобби/сервер (фаза 3).

@export var debug_run_length: float = 120.0   # короткий день для теста (реальные сек); боевое — 1800
@export var use_planning: bool = true          # фаза планирования (ParkGreybox); тест горки — false

func _ready() -> void:
	GameConstants.run_length = debug_run_length
	WeightSystem.reset()
	RunState.reset()
	RunState.coins = 30   # DEBUG: больше монет, чтобы можно было переесть до лока ≥91 кг
	Hype.roll()
	RunState.main_quest = QuestGenerator.generate_main()
	print("[Run] горка дня = %s, день = %.0f сек, атомов в квесте = %d" % [
		Hype.day_slide, debug_run_length, RunState.main_quest.size()])
	if use_planning:
		EventBus.run_planning_started.emit()   # старт дня запускает PlanningOverlay
	else:
		Clock.start_run()
		EventBus.run_started.emit()
