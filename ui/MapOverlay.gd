extends CanvasLayer
## Карта (M) — заглушка фазы 1. Приватная памятка: время, горка дня (Гул),
## главный квест и прогресс. Позже здесь будут метки и миникарта (фаза 2–3).
## День НЕ ставится на паузу — это быстрый взгляд на ходу.

@onready var _body: Label = $Center/Panel/Margin/V/Body

func _ready() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map") and Clock.running:
		visible = not visible

func _process(_delta: float) -> void:
	if not visible:
		return
	_body.text = _format()

func _format() -> String:
	var s := "Время: %s\n" % Clock.game_time_string()
	s += "Горка дня (Гул): %s\n\n" % Hype.day_slide
	s += "Главный квест:\n"
	for i in RunState.main_quest.size():
		var a: Dictionary = RunState.main_quest[i]
		var mark := "✓" if QuestTracker.is_done(i) else "•"
		s += "   %s %s\n" % [mark, str(a.get("name", "?"))]
	s += "\nОчки: %d   Прокатились: %d горок\n" % [RunState.score, RunState.rides_total]
	s += "Сожжено: %.0f ккал" % WeightSystem.calories_burned
	return s
