extends Node3D
## Запуск забега в тестовой сцене: бросает Гул, сбрасывает вес/монеты,
## запускает часы дня. Позже это возьмёт на себя лобби/сервер (фаза 3).

@export var debug_run_length: float = 120.0   # короткий день для теста (реальные сек); боевое — 1800

func _ready() -> void:
	GameConstants.run_length = debug_run_length
	WeightSystem.reset()
	RunState.reset()
	Hype.roll()
	Clock.start_run()
	EventBus.run_started.emit()
	print("[Run] старт: горка дня = %s, день = %.0f сек" % [Hype.day_slide, debug_run_length])
