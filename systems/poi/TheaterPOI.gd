extends Area3D
class_name TheaterPOI
## Театр (POI) с расписанием шоу (Clock.SHOW_SLOTS):
##  • открыт за 1 игровой час до шоу — ворота открыты, заходи;
##  • вошёл до начала → приветствие + обратный отсчёт до старта;
##  • идёт шоу → отсчёт до конца, НОВЫХ не впускают (ворота закрыты);
##  • конец → спасибо + очки (SHOW_PTS), посещение засчитано для квеста (QuestTracker).

var player_inside: bool = false

var _gate: CSGBox3D
var _phase: String = "closed"
var _shown_phase: String = ""
var _slot_i: int = -1
var _running_slot: int = -1
var _awarded_slot: int = -1
var _entered_for_show: bool = false
var _toast_acc: float = 0.0
var _nausea_acc: float = 0.0   # лечение тошноты, пока сидишь в театре
var _results_board: Label3D    # экран итогов на сцене (финальное представление)

func _ready() -> void:
	add_to_group("poi_theater")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 4, 6)
	cs.shape = box
	add_child(cs)

	var stage := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(6, 0.5, 6)
	stage.mesh = bm
	stage.material_override = _mat(Color(0.5, 0.3, 0.6))
	stage.position = Vector3(0, 0.25, 0)
	add_child(stage)

	# Стены (3 шт.) + ворота спереди (-Z), которые открываются на время входа.
	_wall(Vector3(0, 1.5, 3.5), Vector3(7.4, 3, 0.4))   # зад
	_wall(Vector3(3.5, 1.5, 0), Vector3(0.4, 3, 7.4))   # право
	_wall(Vector3(-3.5, 1.5, 0), Vector3(0.4, 3, 7.4))  # лево
	_gate = CSGBox3D.new()
	_gate.size = Vector3(7.4, 3, 0.4)
	_gate.use_collision = true
	_gate.position = Vector3(0, 1.5, -3.5)
	_gate.material_override = _mat(Color(0.7, 0.5, 0.3))
	add_child(_gate)

	var label := Label3D.new()
	label.text = "ТЕАТР"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.pixel_size = 0.012
	label.outline_size = 10
	label.position = Vector3(0, 3.4, 0)
	add_child(label)

	# Экран на сцене — на финальном представлении показывает итоги дня.
	_results_board = Label3D.new()
	_results_board.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_results_board.font_size = 40
	_results_board.pixel_size = 0.01
	_results_board.outline_size = 8
	_results_board.modulate = Color(1.0, 0.92, 0.5)
	_results_board.position = Vector3(0, 2.2, 2.8)
	_results_board.visible = false
	add_child(_results_board)

	body_entered.connect(_on_enter)
	body_exited.connect(func(b): if b is PlayerController: player_inside = false)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m

func _wall(pos: Vector3, size: Vector3) -> void:
	var w := CSGBox3D.new()
	w.size = size
	w.use_collision = true
	w.position = pos
	w.material_override = _mat(Color(0.4, 0.28, 0.45))
	add_child(w)

func _on_enter(b: Node3D) -> void:
	if not (b is PlayerController):
		return
	player_inside = true
	if _phase == "open":
		EventBus.toast.emit("Добро пожаловать в театр! Скоро начнётся представление.")
		_entered_for_show = true
	elif _phase == "running":
		EventBus.toast.emit("Шоу уже идёт — вход закрыт.")

func _process(delta: float) -> void:
	_recalc_phase()
	# Ворота закрыты вне фазы "open", НО не запирают, пока внутри кто-то есть
	# (закрываются только когда все вышли — иначе не выбраться).
	var solid := _phase != "open" and not player_inside
	if _gate.use_collision != solid:
		_gate.use_collision = solid
		_gate.visible = solid

	# Пока сидишь в театре — потихоньку отпускает тошнота (релакс зрелищем).
	if player_inside and RunState.dizziness > 0:
		_nausea_acc += 0.6 * delta
		while _nausea_acc >= 1.0:
			_nausea_acc -= 1.0
			RunState.add_dizziness(-1)

	_toast_acc -= delta
	if player_inside and _toast_acc <= 0.0 and _slot_i >= 0:
		_toast_acc = 3.0
		var s: float = GameConstants.SHOW_SLOTS[_slot_i]
		if _phase == "open":
			EventBus.toast.emit("До начала шоу: %.0f с" % _frac_to_sec(s - Clock.day_fraction))
		elif _phase == "running":
			EventBus.toast.emit("Идёт шоу! До конца: %.0f с" % _frac_to_sec(s + GameConstants.SHOW_DURATION_FRAC - Clock.day_fraction))

	# Старт шоу — запомнить слот.
	if _phase == "running" and _shown_phase != "running":
		_running_slot = _slot_i
	# Конец шоу — спасибо + очки тем, кто был внутри.
	if _shown_phase == "running" and _phase != "running":
		if _entered_for_show and player_inside and _awarded_slot != _running_slot:
			_awarded_slot = _running_slot
			RunState.add_score(GameConstants.SHOW_PTS)
			RunState.add_dizziness(-5)   # отдохнул на шоу — тошнота отступила
			EventBus.toast.emit("Спасибо за посещение! +%d очков, тошнота спала." % GameConstants.SHOW_PTS)
		_entered_for_show = false
	_shown_phase = _phase

	# Финальное представление (последний слот) = подведение итогов на сцене.
	var is_final := _slot_i == GameConstants.SHOW_SLOTS.size() - 1 and _phase == "running"
	_results_board.visible = is_final
	if is_final:
		_results_board.text = _results_text()
		if player_inside:
			RunState.finale_attended = true

func _results_text() -> String:
	var total := RunState.main_quest.size()
	var done := 0
	for i in total:
		if QuestTracker.is_done(i):
			done += 1
	return "🏆 ПОДВЕДЕНИЕ ИТОГОВ\nОчки: %d\nГорок проехано: %d\nКалорий сожжено: %.0f\nГлавный квест: %d/%d\nВес на финише: %.0f кг" % [
		RunState.score, RunState.rides_total, WeightSystem.calories_burned, done, total, WeightSystem.kg]

func _recalc_phase() -> void:
	var df := Clock.day_fraction
	_slot_i = -1
	for i in GameConstants.SHOW_SLOTS.size():
		if df < GameConstants.SHOW_SLOTS[i] + GameConstants.SHOW_DURATION_FRAC:
			_slot_i = i
			break
	if _slot_i < 0:
		_phase = "closed"
		return
	var s: float = GameConstants.SHOW_SLOTS[_slot_i]
	if df < s - GameConstants.SHOW_OPEN_BEFORE_FRAC:
		_phase = "closed"
	elif df < s:
		_phase = "open"
	elif df < s + GameConstants.SHOW_DURATION_FRAC:
		_phase = "running"
	else:
		_phase = "closed"

func _frac_to_sec(f: float) -> float:
	return maxf(f, 0.0) * GameConstants.run_length
