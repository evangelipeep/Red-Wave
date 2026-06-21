extends Node3D
## Запуск забега в тестовой сцене: бросает Гул, сбрасывает вес/монеты,
## запускает часы дня. Позже это возьмёт на себя лобби/сервер (фаза 3).

@export var debug_run_length: float = 1200.0   # полноценный день разработки — 20 минут
@export var use_planning: bool = true          # фаза планирования (ParkGreybox); тест горки — false
@export var use_lobby: bool = true             # старт в раздевалке; день стартует при входе в парк
@export var hard_mode: bool = false            # сложный режим: штрафы за невыполненные квесты

const BALLAD_RADIUS := 13.0   # «красный круг» в центре — куда надо прийти к финалу

var _ballad_started: bool = false
var _ballad_attended: bool = false
var _guard_spawned: bool = false
var _day_started: bool = false

func _ready() -> void:
	GameConstants.run_length = debug_run_length
	WeightSystem.reset()
	RunState.reset()
	RunState.coins = 30   # DEBUG: больше монет, чтобы можно было переесть до лока ≥91 кг
	EventBus.scheduled_event.connect(_on_scheduled)
	EventBus.guard_alert.connect(_on_guard_alert)
	Clock.day_finished.connect(_on_day_end)
	# Если сеть уже поднята из cmdline (--host/--join) или режим --single — стартуем сразу.
	# Иначе ждём выбора в лобби (LobbyOverlay вызовет begin_local/begin_remote).
	var args := OS.get_cmdline_user_args()
	if Net.is_online():
		if Net.is_server():
			begin_local()
		else:
			begin_remote()
	elif "--single" in args:
		begin_local(true)   # headless/быстрый запуск: без раздевалки, день сразу
	# else: лобби покажет экран и сам вызовет begin_local/begin_remote по кнопке.

## Хост или одиночная: бросает Гул, генерит квест дня. Затем раздевалка (день стартует
## при входе в парк через розовые двери) или сразу день (skip_prep — тесты/тест-сцена).
func begin_local(skip_prep := false) -> void:
	Hype.roll()
	RunState.main_quest = QuestGenerator.generate_main()
	RunState.personal_quest = QuestGenerator.generate_personal()
	RunState.assign_locker()
	print("[Run] горка дня = %s, день = %.0f сек, атомов в квесте = %d" % [
		Hype.day_slide, debug_run_length, RunState.main_quest.size()])
	if use_lobby and not skip_prep:
		EventBus.prep_started.emit()           # раздевалка: ходишь, часы стоят
	elif use_planning and not skip_prep:
		EventBus.run_planning_started.emit()   # старая фаза планирования (PlanningOverlay)
	else:
		_start_day()

## Клиент в сети: свой Гул не катит, ждёт день от хоста (CoopManager._sync_session).
## В раздевалку попадает сразу (prep), день применит синхрон от хоста.
func begin_remote() -> void:
	RunState.personal_quest = QuestGenerator.generate_personal()
	RunState.assign_locker()
	if use_lobby:
		EventBus.prep_started.emit()
	print("[Run] клиент: раздевалка, ожидание дня от хоста…")

## Вход в парк через розовые двери (LobbyBuilder зовёт). Запускает день у хоста/одиночки.
func enter_park() -> void:
	if _day_started:
		return
	if Net.is_online() and not Net.is_server():
		return   # клиент ждёт день от хоста (синхрон), сам не стартует
	_start_day()

func _start_day() -> void:
	if _day_started:
		return
	_day_started = true
	Clock.start_run()
	EventBus.run_started.emit()

func _on_guard_alert(_level: int) -> void:
	if _guard_spawned:
		return
	_guard_spawned = true
	var g := Guard.new()
	get_tree().current_scene.add_child(g)
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var p := players[0] as Node3D
		g.global_position = p.global_position + Vector3(3, 0, 3)
	EventBus.toast.emit("За вами теперь следит охрана…")

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
	# Сложный режим: штрафы за невыполненные квесты (GDD, заморожено).
	if hard_mode:
		if not QuestTracker.quest_complete():
			RunState.add_score(GameConstants.HARD_MAIN_FAIL)
			EventBus.toast.emit("Сложный режим: главный квест провален (%d)" % GameConstants.HARD_MAIN_FAIL)
		if not RunState.personal_quest.is_empty() and not QuestTracker.personal_is_done():
			RunState.add_score(GameConstants.HARD_PERSONAL_FAIL)
			EventBus.toast.emit("Сложный режим: личное провалено (%d)" % GameConstants.HARD_PERSONAL_FAIL)
	# Штраф за Балладу только в настоящем парке (где есть зоны), не в тест-сцене.
	if get_tree().get_nodes_in_group("zone").is_empty():
		return
	if _ballad_started and not _ballad_attended:
		RunState.add_score(GameConstants.MISS_BALLAD)
		EventBus.toast.emit("Пропустил Балладу! %d очка" % GameConstants.MISS_BALLAD)
