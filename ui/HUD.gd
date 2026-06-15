extends CanvasLayer
## Минимальный HUD фазы 1: время+фаза дня, вес (+сжигание), монеты, голова.
## Тянет данные из автолоадов напрямую (просто и достаточно для прототипа).

@onready var _time: Label = $VBox/Time
@onready var _weight: Label = $VBox/Weight
@onready var _coins: Label = $VBox/Coins
@onready var _dizzy: Label = $VBox/Dizzy
@onready var _hint: Label = $VBox/Hint

func _ready() -> void:
	_hint.text = "E — снек (+1кг)   Q — блюдо (+2кг)   T — туалет (−3кг)"

func _process(_delta: float) -> void:
	_time.text = "%s   (%s)" % [Clock.game_time_string(), _phase_ru(Clock.phase())]
	var lock := "  ⛔экстрим" if not WeightSystem.can_ride_extreme() else ""
	_weight.text = "Вес: %.1f кг   сожжено %.2f/1.0%s" % [
		WeightSystem.kg, WeightSystem.burn_progress(), lock]
	_coins.text = "Монеты: %d" % RunState.coins
	_dizzy.text = "Голова: %d/%d" % [RunState.dizziness, GameConstants.DIZZY_MAX]

func _phase_ru(p: String) -> String:
	match p:
		"morning": return "утро"
		"noon": return "полдень"
		"evening": return "вечер"
		"finale": return "финал"
		_: return "планирование"
