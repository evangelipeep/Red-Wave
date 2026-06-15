extends CanvasLayer
## Минимальный HUD фазы 1: время+фаза, калории (это игрок и будет видеть),
## вес (пока для отладки — позже спрячем за пункты взвешивания), монеты, голова,
## статус туалета. Плюс всплывающие тосты (EventBus.toast).

@onready var _time: Label = $VBox/Time
@onready var _cal: Label = $VBox/Calories
@onready var _weight: Label = $VBox/Weight
@onready var _coins: Label = $VBox/Coins
@onready var _dizzy: Label = $VBox/Dizzy
@onready var _toilet: Label = $VBox/Toilet
@onready var _hint: Label = $VBox/Hint
@onready var _toast: Label = $ToastWrap/Toast

var _toast_time: float = 0.0

func _ready() -> void:
	_toast.text = ""
	_hint.text = "WASD ходьба · Shift бег · Space прыжок · E снек · Q блюдо · T туалет"
	EventBus.toast.connect(_on_toast)

func _process(delta: float) -> void:
	_time.text = "%s   (%s)" % [Clock.game_time_string(), _phase_ru(Clock.phase())]
	_cal.text = "Сожжено: %.0f ккал" % WeightSystem.calories_burned
	var lock := "  ⛔экстрим" if not WeightSystem.can_ride_extreme() else ""
	_weight.text = "Вес (отладка): %.1f кг   к −1кг %.0f%%%s" % [
		WeightSystem.kg, WeightSystem.burn_progress() * 100.0, lock]
	_coins.text = "Монеты: %d" % RunState.coins
	_dizzy.text = "Голова: %d/%d" % [RunState.dizziness, GameConstants.DIZZY_MAX]
	if WeightSystem.can_toilet():
		_toilet.text = "Туалет: готов"
	else:
		_toilet.text = "Туалет: через %.1f ч" % WeightSystem.toilet_ready_in_hours()

	if _toast_time > 0.0:
		_toast_time -= delta
		if _toast_time <= 0.0:
			_toast.text = ""

func _on_toast(message: String) -> void:
	_toast.text = message
	_toast_time = 3.0

func _phase_ru(p: String) -> String:
	match p:
		"morning": return "утро"
		"noon": return "полдень"
		"evening": return "вечер"
		"finale": return "финал"
		_: return "планирование"
