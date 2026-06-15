extends CanvasLayer
## Карта (M): на весь экран. Слева — карточки заданий со статусом (в процессе /
## выполнено / провалено), справа — карта парка с метками (ЛКМ ставит, ПКМ убирает).
## Открытие ставит игру на паузу (process_mode=ALWAYS у этого узла).

@onready var _cards: VBoxContainer = $HBox/Left/Scroll/Cards
@onready var _map: MapView = $HBox/Right/BigMap

var _open: bool = false
var _card_lbls: Array = []   # [{lbl, sb, i, atom}]

func _ready() -> void:
	visible = false
	EventBus.run_started.connect(_rebuild_cards)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map") and (Clock.running or _open):
		_toggle()

func _toggle() -> void:
	_open = not _open
	visible = _open
	get_tree().paused = _open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _open else Input.MOUSE_MODE_CAPTURED
	if _open:
		_rebuild_cards()

func _process(_delta: float) -> void:
	if visible:
		_update_cards()

func _rebuild_cards() -> void:
	for c in _cards.get_children():
		c.queue_free()
	_card_lbls.clear()
	for i in RunState.main_quest.size():
		var atom: Dictionary = RunState.main_quest[i]
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(14)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", sb)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lbl := Label.new()
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(lbl)
		_cards.add_child(card)
		_card_lbls.append({"lbl": lbl, "sb": sb, "i": i, "atom": atom})
	_update_cards()

func _update_cards() -> void:
	for e in _card_lbls:
		var i: int = e["i"]
		var atom_name: String = str((e["atom"] as Dictionary).get("name", "?"))
		var st := _status(i)
		var word := ""
		match st:
			"done":
				(e["sb"] as StyleBoxFlat).bg_color = Color(0.18, 0.45, 0.24)
				word = "Выполнено ✓"
			"failed":
				(e["sb"] as StyleBoxFlat).bg_color = Color(0.48, 0.18, 0.18)
				word = "Провалено ✗"
			_:
				(e["sb"] as StyleBoxFlat).bg_color = Color(0.20, 0.22, 0.28)
				word = "В процессе…"
		(e["lbl"] as Label).text = "%s\n[%s]" % [atom_name, word]

func _status(i: int) -> String:
	if QuestTracker.is_done(i):
		return "done"
	if not Clock.running and Clock.day_fraction >= 1.0:
		return "failed"
	return "active"
