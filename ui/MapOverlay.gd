extends CanvasLayer
## Карта (M): «КАРТА / Кровавый аквапарк». Слева панель ЗАДАНИЯ с карточками
## (иконка-акцент, название, прогресс, статус), справа карта с метками. Открытие
## ставит игру на паузу. ЛКМ — метка, ПКМ — убрать, колесо — зум, M/ESC — выход.

@onready var _cards: VBoxContainer = $Margin/Root/Body/Left/Scroll/Cards
@onready var _tasks_head: Label = $Margin/Root/Body/Left/Head
@onready var _map: MapView = $Margin/Root/Body/Right/BigMap

var _open: bool = false
var _entries: Array = []   # [{title, sub, accent, i}]

func _ready() -> void:
	visible = false
	EventBus.run_started.connect(_rebuild_cards)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map") and (Clock.running or _open):
		_toggle()
	elif _open and event.is_action_pressed("ui_cancel"):
		_toggle()

func _toggle() -> void:
	_open = not _open
	visible = _open
	# Без паузы — мир продолжает жить (онлайн). Только курсор + заморозка управления.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _open else Input.MOUSE_MODE_CAPTURED
	EventBus.map_opened.emit(_open)
	if _open:
		_rebuild_cards()

func _process(_delta: float) -> void:
	if visible:
		_update_cards()

func _rebuild_cards() -> void:
	for c in _cards.get_children():
		c.queue_free()
	_entries.clear()
	for i in RunState.main_quest.size():
		_make_card(RunState.main_quest[i], Color(0.12, 0.13, 0.17, 0.95), i, false)
	if not RunState.personal_quest.is_empty():
		_make_card(RunState.personal_quest[0], Color(0.14, 0.11, 0.18, 0.95), -1, true)
	_update_cards()

# Карточка задания: заголовок + статус, и раскрывающаяся подсказка (клик → плавно растёт).
func _make_card(atom: Dictionary, bg: Color, i: int, personal: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.bg_color = bg
	sb.border_width_left = 6
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", sb)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 17)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sub := Label.new()
	sub.add_theme_font_size_override("font_size", 13)
	sub.modulate = Color(0.75, 0.78, 0.85)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(title)
	v.add_child(sub)
	# Раскрывающаяся часть: плоский Control с обрезкой; высоту анимируем твином.
	var wrap := Control.new()
	wrap.clip_contents = true
	wrap.custom_minimum_size = Vector2(0, 0)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(wrap)
	var detail := Label.new()
	detail.add_theme_font_size_override("font_size", 13)
	detail.modulate = Color(0.82, 0.9, 1.0)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size.x = 250
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.text = QuestGenerator.describe(atom)
	wrap.add_child(detail)
	detail.size = Vector2(250, detail.get_minimum_size().y)
	detail.position = Vector2.ZERO
	_cards.add_child(card)
	var entry := {"title": title, "sub": sub, "accent": sb, "i": i, "personal": personal,
		"wrap": wrap, "detail": detail, "expanded": false}
	card.gui_input.connect(_on_card_input.bind(entry))
	_entries.append(entry)

func _on_card_input(event: InputEvent, entry: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		entry["expanded"] = not entry["expanded"]
		var wrap: Control = entry["wrap"]
		var detail: Label = entry["detail"]
		var target := (detail.get_minimum_size().y + 6.0) if entry["expanded"] else 0.0
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(wrap, "custom_minimum_size:y", target, 0.22)

func _update_cards() -> void:
	_tasks_head.text = "ЗАДАНИЯ   %d" % RunState.main_quest.size()
	for e in _entries:
		var personal: bool = e.get("personal", false)
		var atom: Dictionary
		var pr: Vector2i
		var st: String
		var prefix := ""
		if personal:
			if RunState.personal_quest.is_empty():
				continue
			atom = RunState.personal_quest[0]
			pr = QuestTracker.personal_progress()
			st = _status_personal()
			prefix = "★ Личное: "
		else:
			var i: int = e["i"]
			atom = RunState.main_quest[i]
			pr = QuestTracker.progress(i)
			st = _status(i)
		var accent: Color
		var word: String
		match st:
			"done":
				accent = Color(0.3, 0.85, 0.4)
				word = "Выполнено"
			"failed":
				accent = Color(0.9, 0.3, 0.3)
				word = "Провалено"
			_:
				accent = Color(0.85, 0.2, 0.25)
				word = "В процессе"
		(e["accent"] as StyleBoxFlat).border_color = accent
		(e["title"] as Label).text = prefix + str(atom.get("name", "?"))
		(e["sub"] as Label).text = "%s   %d/%d" % [word, pr.x, pr.y]

func _status_personal() -> String:
	if QuestTracker.personal_is_done():
		return "done"
	if not Clock.running and Clock.day_fraction >= 1.0:
		return "failed"
	return "active"

func _status(i: int) -> String:
	if QuestTracker.is_done(i):
		return "done"
	if not Clock.running and Clock.day_fraction >= 1.0:
		return "failed"
	return "active"
