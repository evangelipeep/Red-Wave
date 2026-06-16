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
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(12)
		sb.bg_color = Color(0.12, 0.13, 0.17, 0.95)
		sb.border_width_left = 6
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", sb)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := VBoxContainer.new()
		card.add_child(v)
		var title := Label.new()
		title.add_theme_font_size_override("font_size", 17)
		var sub := Label.new()
		sub.add_theme_font_size_override("font_size", 13)
		sub.modulate = Color(0.75, 0.78, 0.85)
		v.add_child(title)
		v.add_child(sub)
		_cards.add_child(card)
		_entries.append({"title": title, "sub": sub, "accent": sb, "i": i})
	if not RunState.personal_quest.is_empty():
		_add_personal_card()
	_update_cards()

func _add_personal_card() -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.bg_color = Color(0.14, 0.11, 0.18, 0.95)
	sb.border_width_left = 6
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", sb)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	card.add_child(v)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 17)
	var sub := Label.new()
	sub.add_theme_font_size_override("font_size", 13)
	sub.modulate = Color(0.75, 0.78, 0.85)
	v.add_child(title)
	v.add_child(sub)
	_cards.add_child(card)
	_entries.append({"title": title, "sub": sub, "accent": sb, "i": -1, "personal": true})

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
