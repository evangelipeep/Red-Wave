extends CanvasLayer
## Финал дня — «Баллада Красной Реки» (GDD §финал). Табло: итоги забега и
## рекорды веса. Enter — заново. Показывается по Clock.day_finished.
## Проверка выполнения главного квеста и начисление очков — фаза 2 (QuestTracker).

@onready var _body: Label = $Center/Panel/Margin/V/Body

func _ready() -> void:
	visible = false
	Clock.day_finished.connect(_on_day_finished)

func _on_day_finished() -> void:
	visible = true
	_body.text = _format()

func _process(_delta: float) -> void:
	if visible and Input.is_action_just_pressed("ui_accept"):
		get_tree().reload_current_scene()

func _format() -> String:
	var s := "Парк закрывается. Красная река, один голос, последний круг…\n\n"
	s += "ИТОГИ ДНЯ\n"
	s += "   Горок проехано: %d\n" % RunState.rides_total
	s += "   Калорий сожжено: %.0f\n" % WeightSystem.calories_burned
	s += "   Вес: финиш %.1f кг  (мин %.1f / макс %.1f)\n" % [
		WeightSystem.kg, WeightSystem.weight_min, WeightSystem.weight_max]
	s += "   Голова (пик за день): %d/%d\n" % [RunState.dizziness_peak, GameConstants.DIZZY_MAX]
	s += "   Монет осталось: %d\n\n" % RunState.coins
	var status := "ВЫПОЛНЕН ✓" if QuestTracker.quest_complete() else "не выполнен"
	s += "Главный квест: %s\n" % status
	for i in RunState.main_quest.size():
		var a: Dictionary = RunState.main_quest[i]
		var mark := "✓" if QuestTracker.is_done(i) else "✗"
		s += "   %s %s\n" % [mark, str(a.get("name", "?"))]
	s += "\nОЧКИ ЗА ДЕНЬ: %d\n\n" % RunState.score
	s += "Enter — заново"
	return s
