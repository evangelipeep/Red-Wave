extends CanvasLayer
## Минимальный HUD фазы 1: время+фаза, калории (это игрок и будет видеть),
## вес (пока для отладки — позже спрячем за пункты взвешивания), монеты, голова,
## статус туалета. Плюс всплывающие тосты (EventBus.toast).

@onready var _time: Label = $VBox/Time
@onready var _objective: Label = $VBox/Objective
@onready var _cal: Label = $VBox/Calories
@onready var _weight: Label = $VBox/Weight
@onready var _coins: Label = $VBox/Coins
@onready var _score: Label = $VBox/Score
@onready var _dizzy: Label = $VBox/Dizzy
@onready var _toilet: Label = $VBox/Toilet
@onready var _zone: Label = $VBox/Zone
@onready var _queue: Label = $VBox/Queue
@onready var _hint: Label = $VBox/Hint
@onready var _toast: Label = $ToastWrap/Toast

var _toast_time: float = 0.0
var _queue_text: String = ""

# Фуд-корт UI (строится в коде): слоты инвентаря, пищалки, строка бафов.
var _slots: Array = []        # [{panel, swatch, label}] ×4
var _buzz: Array = []         # [{chip, dot, label}] ×5
var _buffs_label: Label

func _ready() -> void:
	_toast.text = ""
	_hint.text = "WASD · Shift бег · Space прыжок · E взаимод · F есть · 1-4 слот · G выброс · T туалет · M карта · СКМ пинг"
	EventBus.toast.connect(_on_toast)
	EventBus.queue_update.connect(_on_queue)
	_build_food_ui()

func _on_queue(_slide_id: String, ahead: float, active: bool) -> void:
	if not active:
		_queue_text = ""
	elif int(ahead) <= 0:
		_queue_text = "Вы следующий — заходите!"
	else:
		_queue_text = "В очереди: впереди %d" % int(ahead)

func _process(delta: float) -> void:
	_time.text = "%s   (%s)" % [Clock.game_time_string(), _phase_ru(Clock.phase())]
	_objective.text = _objective_text()
	_cal.text = "Сожжено: %.0f ккал" % WeightSystem.calories_burned
	# Точный вес скрыт — только состояние (число узнаёшь на весах).
	_weight.text = "Состояние: %s   (к −1кг %.0f%%)" % [
		_weight_band(), WeightSystem.burn_progress() * 100.0]
	_coins.text = "Монеты: %d" % RunState.coins
	_score.text = "Очки: %d" % RunState.score
	_dizzy.text = "Тошнота: %s %d/%d" % [_nausea_bar(), RunState.dizziness, GameConstants.DIZZY_MAX]
	if RunState.dizziness >= GameConstants.DIZZY_MAX:
		_dizzy.modulate = Color(1.0, 0.3, 0.3)        # полная — красная
	elif RunState.dizziness >= GameConstants.NAUSEA_WARN:
		_dizzy.modulate = Color(1.0, 0.7, 0.3)        # высокая — оранжевая
	else:
		_dizzy.modulate = Color(0.4, 0.9, 0.4)        # норма — зелёная (как HP)
	if WeightSystem.can_toilet():
		_toilet.text = "Туалет: готов"
	else:
		_toilet.text = "Туалет: через %.1f ч" % WeightSystem.toilet_ready_in_hours()
	_zone.text = "Зона: %s" % _zone_ru(RunState.current_zone)
	if _queue_text != "":
		_queue.text = _queue_text
	elif RunState.run_blocked:
		_queue.text = "🚫 Бег заблокирован — отстойте очереди честно"
	else:
		_queue.text = ""

	_update_food_ui()

	if _toast_time > 0.0:
		_toast_time -= delta
		if _toast_time <= 0.0:
			_toast.text = ""

func _on_toast(message: String) -> void:
	_toast.text = message
	_toast_time = 3.0

func _objective_text() -> String:
	var total := RunState.main_quest.size()
	if total == 0:
		return ""
	var done := 0
	var todo := ""
	for i in total:
		if QuestTracker.is_done(i):
			done += 1
		elif todo == "":
			todo = str((RunState.main_quest[i] as Dictionary).get("name", "?"))
	if todo == "":
		todo = "всё выполнено ✓"
	return "Цель (%d/%d): %s" % [done, total, todo]

func _nausea_bar() -> String:
	var s := ""
	for i in GameConstants.DIZZY_MAX:
		s += "█" if i < RunState.dizziness else "░"
	return s

func _weight_band() -> String:
	if not WeightSystem.can_ride_extreme():
		return "⛔ перебор — на экстрим не пустят"
	if WeightSystem.kg >= 88.0:
		return "тяжеловато"
	if WeightSystem.kg <= 73.0:
		return "налегке"
	return "в норме"

func _zone_ru(z: String) -> String:
	match z:
		"klyk": return "Северный Клык"
		"delta": return "Дельта"
		"zero": return "Серый Пояс Зеро"
		_: return "центр"

func _phase_ru(p: String) -> String:
	match p:
		"morning": return "утро"
		"noon": return "полдень"
		"evening": return "вечер"
		"finale": return "финал"
		_: return "планирование"

# --- Фуд-корт: бар инвентаря (4 слота), пищалки (до 5), строка бафов. ---
func _build_food_ui() -> void:
	var inv := HBoxContainer.new()
	add_child(inv)
	inv.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	inv.grow_horizontal = Control.GROW_DIRECTION_BOTH
	inv.grow_vertical = Control.GROW_DIRECTION_BEGIN
	inv.offset_bottom = -14
	inv.add_theme_constant_override("separation", 8)
	for i in 4:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(104, 60)
		inv.add_child(p)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		p.add_child(v)
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(0, 22)
		v.add_child(sw)
		var lb := Label.new()
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.add_theme_font_size_override("font_size", 13)
		v.add_child(lb)
		_slots.append({"panel": p, "swatch": sw, "label": lb})

	var buzz := HBoxContainer.new()
	add_child(buzz)
	buzz.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	buzz.grow_horizontal = Control.GROW_DIRECTION_BOTH
	buzz.grow_vertical = Control.GROW_DIRECTION_BEGIN
	buzz.offset_bottom = -82
	buzz.add_theme_constant_override("separation", 6)
	for i in 5:
		var chip := PanelContainer.new()
		chip.visible = false
		buzz.add_child(chip)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		chip.add_child(h)
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(14, 14)
		h.add_child(dot)
		var lb := Label.new()
		lb.add_theme_font_size_override("font_size", 13)
		h.add_child(lb)
		_buzz.append({"chip": chip, "dot": dot, "label": lb})

	_buffs_label = Label.new()
	_buffs_label.add_theme_font_size_override("font_size", 15)
	_buffs_label.modulate = Color(0.6, 1.0, 0.8)
	$VBox.add_child(_buffs_label)

func _update_food_ui() -> void:
	for i in 4:
		var s: Dictionary = _slots[i]
		if i < RunState.trays.size():
			var tray: Dictionary = RunState.trays[i]
			(s["swatch"] as ColorRect).color = tray["color"]
			(s["label"] as Label).text = "%d· %s ×%d" % [
				i + 1, FoodMenu.stall_name(tray["stall_id"]), (tray["dishes"] as Array).size()]
			(s["panel"] as Control).modulate = Color(1, 1, 1) if i == RunState.selected_slot else Color(0.65, 0.65, 0.65)
		else:
			(s["swatch"] as ColorRect).color = Color(0.2, 0.2, 0.2, 0.5)
			(s["label"] as Label).text = "%d· —" % (i + 1)
			(s["panel"] as Control).modulate = Color(0.5, 0.5, 0.5)

	for i in 5:
		var b: Dictionary = _buzz[i]
		if i < RunState.pending_orders.size():
			var o: Dictionary = RunState.pending_orders[i]
			(b["chip"] as Control).visible = true
			(b["dot"] as ColorRect).color = o["color"]
			var ready := RunState.order_is_ready(o)
			var nm := FoodMenu.stall_name(o["stall_id"])
			(b["label"] as Label).text = ("🔔 %s готов" % nm) if ready else ("%s… готовится" % nm)
			(b["label"] as Label).modulate = Color(1, 0.9, 0.3) if ready else Color(0.8, 0.8, 0.8)
		else:
			(b["chip"] as Control).visible = false

	var parts: Array = []
	for e in PlayerBuffs.active_list():
		parts.append(_buff_ru(e))
	_buffs_label.text = ("Эффекты: " + ", ".join(parts)) if not parts.is_empty() else ""

func _buff_ru(e: Dictionary) -> String:
	var names := {
		"caffeine": "Кофеин ×2", "heavy": "Тяжесть ×0.8",
		"hotsoup": "Суп ×1.5 кал", "spicy": "Острое (туалет)",
	}
	var t := str(names.get(e["id"], e["id"]))
	if float(e["min"]) > 0.0:
		return "%s (%.0fм)" % [t, float(e["min"])]
	return t
