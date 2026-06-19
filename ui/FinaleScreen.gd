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
	if not visible:
		return
	_body.text = _format()   # подхватываем поздние начисления (Баллада, доплата квеста)
	if Input.is_action_just_pressed("ui_accept"):
		get_tree().reload_current_scene()

func _format() -> String:
	var s := "Парк закрывается. Красная река, один голос, последний круг…\n\n"
	s += "ИТОГИ ДНЯ\n"
	s += "   Горок проехано: %d\n" % RunState.rides_total
	s += "   Калорий сожжено: %.0f\n" % WeightSystem.calories_burned
	s += "   Вес: финиш %.1f кг  (мин %.1f / макс %.1f)\n" % [
		WeightSystem.kg, WeightSystem.weight_min, WeightSystem.weight_max]
	s += "   Тошнота (пик за день): %d/%d\n" % [RunState.dizziness_peak, GameConstants.DIZZY_MAX]
	s += "   Монет осталось: %d\n\n" % RunState.coins
	var status := "ВЫПОЛНЕН ✓" if QuestTracker.quest_complete() else "не выполнен"
	s += "Главный квест: %s\n" % status
	for i in RunState.main_quest.size():
		var a: Dictionary = RunState.main_quest[i]
		var mark := "✓" if QuestTracker.is_done(i) else "✗"
		s += "   %s %s\n" % [mark, str(a.get("name", "?"))]
	if not RunState.personal_quest.is_empty():
		var pm := "✓" if QuestTracker.personal_is_done() else "✗"
		s += "\n★ Личное: %s %s\n" % [pm, str(RunState.personal_quest[0].get("name", "?"))]
	s += "\nОЧКИ ЗА ДЕНЬ: %d\n" % RunState.score
	s += _coop_board()
	s += "\nEnter — заново"
	return s

func _coop_board() -> String:
	if not Net.is_online():
		return ""
	var coop := get_tree().get_first_node_in_group("coop")
	if coop == null:
		return ""
	var rows: Array = coop.leaderboard()
	if rows.size() < 2:
		return ""   # один игрок — таблица не нужна
	var s := "\nТАБЛО КОМАНДЫ\n"
	var place := 1
	for r in rows:
		var me := "  ← вы" if r["me"] else ""
		s += "   %d. %-10s %d%s\n" % [place, str(r["name"]), int(r["score"]), me]
		place += 1
	return s
