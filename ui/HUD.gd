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
var _slots: Array = []        # [{panel, icon, label}] — пул хотбара
var _buzz: Array = []         # [{chip, dot, label}] ×5
var _buffs_label: Label
var _clock_label: Label   # электронные часы под полоской тошноты
var _tex_pill: Texture2D  # иконки предметов хотбара (или null → эмодзи-фолбэк)
var _tex_gun: Texture2D

const HOTBAR_SLOTS := 6           # пул слотов: до 4 подносов + таблетки + пистолет
const MIN_HOTBAR_SLOTS := 4       # столько пустых слотов видно всегда
var _last_selected: int = -1      # для анимации «отдачи» при смене активного слота

func _ready() -> void:
	_toast.text = ""
	_hint.text = "WASD · Shift бег · Space прыжок · E взаимод · F применить · 1-4/колесо слот · G выброс · T туалет · M карта · СКМ пинг"
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

	if _clock_label != null:
		_clock_label.text = "⌚ %s" % Clock.game_time_string()
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
	if WeightSystem.is_heavy():
		return "🐘 толстый (>90): с горок быстрее, часть экстрима закрыта"
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

# --- Фуд-корт: хотбар (до 6 слотов с иконками), пищалки (до 5), строка бафов. ---
func _build_food_ui() -> void:
	# Рамки слотов берём из Look.slot_style (общая «ячейка» — картинка из assets/ui,
	# иначе плоский фолбэк). Те же слоты переиспользуются для сундуков в будущем.
	_tex_pill = _load_icon("res://assets/ui/pills.png")
	_tex_gun = _load_icon("res://assets/ui/gun.png")
	# Полоса хотбара во всю ширину у нижнего края, слоты по центру (надёжнее, чем
	# точечный CENTER_BOTTOM — тот «расплывался» с контейнером).
	var inv := HBoxContainer.new()
	add_child(inv)
	inv.anchor_left = 0.0
	inv.anchor_right = 1.0
	inv.anchor_top = 1.0
	inv.anchor_bottom = 1.0
	inv.offset_left = 0.0
	inv.offset_right = 0.0
	inv.offset_top = -122.0
	inv.offset_bottom = -10.0
	inv.alignment = BoxContainer.ALIGNMENT_CENTER
	inv.add_theme_constant_override("separation", 8)
	for i in HOTBAR_SLOTS:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(88, 74)
		p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		p.add_theme_stylebox_override("panel", Look.slot_style(false))
		p.visible = false
		inv.add_child(p)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		p.add_child(v)
		# Картинка предмета поверх рамки (если есть иконка) — иначе эмодзи-фолбэк.
		var tex := TextureRect.new()
		tex.custom_minimum_size = Vector2(52, 52)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.visible = false
		v.add_child(tex)
		var icon := Label.new()
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.add_theme_font_size_override("font_size", 30)
		v.add_child(icon)
		var lb := Label.new()
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.add_theme_font_size_override("font_size", 12)
		v.add_child(lb)
		_slots.append({"panel": p, "tex": tex, "icon": icon, "label": lb})

	var buzz := HBoxContainer.new()
	add_child(buzz)
	buzz.anchor_left = 0.0
	buzz.anchor_right = 1.0
	buzz.anchor_top = 1.0
	buzz.anchor_bottom = 1.0
	buzz.offset_top = -176.0
	buzz.offset_bottom = -136.0
	buzz.alignment = BoxContainer.ALIGNMENT_CENTER
	buzz.add_theme_constant_override("separation", 6)
	for i in 5:
		var chip := PanelContainer.new()
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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

	# Электронные часы прямо под полоской тошноты (_dizzy).
	_clock_label = Label.new()
	_clock_label.add_theme_font_size_override("font_size", 26)
	_clock_label.modulate = Color(0.4, 1.0, 0.5)   # зелёные «цифры»
	$VBox.add_child(_clock_label)
	$VBox.move_child(_clock_label, _dizzy.get_index() + 1)

func _load_icon(path: String) -> Texture2D:
	return Look.icon(path)   # общий кэш иконок

# Иконка слота: есть картинка → показываем её (поверх рамки); нет → эмодзи-фолбэк.
func _set_slot_icon(s: Dictionary, t: Texture2D, emoji: String, col: Color) -> void:
	var tex := s["tex"] as TextureRect
	var ic := s["icon"] as Label
	if t != null:
		tex.texture = t
		tex.visible = true
		ic.visible = false
	else:
		tex.visible = false
		ic.visible = true
		ic.text = emoji
		ic.modulate = col

# Хотбар: рисуем единый список снаряжения (подносы + таблетки + пистолет).
func _update_food_ui() -> void:
	var hb := RunState.hotbar()
	var sel := RunState.selected_slot
	# Анимация «отдачи»: пихнуть только что выбранный слот.
	if sel != _last_selected:
		if sel >= 0 and sel < _slots.size():
			_pop_slot((_slots[sel] as Dictionary)["panel"] as Control)
		_last_selected = sel

	# Слоты видны ВСЕГДА (минимум 4 пустых), сверх — занятые таблетками/пистолетом.
	var shown := clampi(maxi(MIN_HOTBAR_SLOTS, hb.size()), 0, _slots.size())
	for i in _slots.size():
		var s: Dictionary = _slots[i]
		var panel := s["panel"] as PanelContainer
		var label := s["label"] as Label
		if i >= shown:
			panel.visible = false
			continue
		panel.visible = true
		var selected := i == sel
		panel.add_theme_stylebox_override("panel", Look.slot_style(selected))
		var key := "%d" % (i + 1) if i < 4 else "·"   # цифры только для первых четырёх
		if i >= hb.size():
			# Пустой слот: только рамка + номер, без иконки.
			(s["tex"] as TextureRect).visible = false
			(s["icon"] as Label).visible = false
			label.text = key
			panel.modulate = Color(0.55, 0.55, 0.55)
			continue
		panel.modulate = Color(1, 1, 1) if selected else Color(0.82, 0.82, 0.82)
		var entry: Dictionary = hb[i]
		match str(entry["kind"]):
			"tray":
				var tray: Dictionary = entry["tray"]
				var dishes := tray["dishes"] as Array
				var dt: Texture2D = FoodMenu.dish_icon(dishes[0]) if not dishes.is_empty() else null
				_set_slot_icon(s, dt, "🍱", tray["color"])
				label.text = "%s ×%d" % [key, dishes.size()]
			"pill":
				_set_slot_icon(s, _tex_pill, "💊", Color.WHITE)
				label.text = "%s ×%d" % [key, int(entry["qty"])]
			"gun":
				_set_slot_icon(s, _tex_gun, "🔫", Color.WHITE)
				var pl = get_tree().get_first_node_in_group("player")
				var ready: bool = pl == null or float(pl.gun_cooldown_ratio()) >= 1.0
				label.text = key if ready else (key + " ⏳")
				if not ready:
					panel.modulate = Color(0.6, 0.6, 0.6)

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

# «Отдача» слота при выборе: коротко увеличить и плавно вернуть к 1.
func _pop_slot(panel: Control) -> void:
	if panel == null:
		return
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(1.25, 1.25)
	var tw := create_tween()
	tw.tween_property(panel, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _buff_ru(e: Dictionary) -> String:
	var names := {
		"caffeine": "Кофеин ×2", "heavy": "Тяжесть ×0.8",
		"hotsoup": "Суп ×1.5 кал", "spicy": "Острое (туалет)",
	}
	var t := str(names.get(e["id"], e["id"]))
	if float(e["min"]) > 0.0:
		return "%s (%.0fм)" % [t, float(e["min"])]
	return t
