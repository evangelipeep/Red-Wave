extends CanvasLayer
## Фаза планирования: пауза перед днём. Часы стоят, игрок заморожен, показан
## сгенерированный главный квест. Enter (или по таймеру PLANNING_WINDOW) — старт дня.

@onready var _title: Label = $Center/Panel/Margin/V/Title
@onready var _quest: Label = $Center/Panel/Margin/V/Quest
@onready var _count: Label = $Center/Panel/Margin/V/Count

var _t: float = 0.0
var _active: bool = false

func _ready() -> void:
	visible = false
	EventBus.run_planning_started.connect(_begin)

func _begin() -> void:
	visible = true
	_active = true
	_t = GameConstants.PLANNING_WINDOW
	_title.text = "Планирование дня — горка дня (Гул): %s" % Hype.day_slide
	_quest.text = _format_quest()

func _process(delta: float) -> void:
	if not _active:
		return
	_t -= delta
	_count.text = "День начнётся через %.0f с    (Enter — начать сейчас)" % maxf(_t, 0.0)
	if _t <= 0.0 or Input.is_action_just_pressed("ui_accept"):
		_start()

func _start() -> void:
	_active = false
	visible = false
	Clock.start_run()
	EventBus.run_started.emit()

func _format_quest() -> String:
	var s := "Главный квест на день:\n"
	for a in RunState.main_quest:
		s += "   • %s\n" % str(a.get("name", "?"))
	s += "\nЗа выполнение: +%d очков." % GameConstants.MAIN_PAYOUT
	return s
