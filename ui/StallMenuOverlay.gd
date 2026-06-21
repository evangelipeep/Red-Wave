extends CanvasLayer
## Красивое меню заказа в лавке (3 колонки):
##   • слева — МЕНЮ: карточки блюд (картинка-иконка, лор-описание в вампирском юморе,
##     баф/дебаф, статы веса/тошноты, кнопка «в заказ»);
##   • по центру — ВАШ ЗАКАЗ: выбранные позиции (можно убрать) и снизу сумма + оплата;
##   • справа — КАССА: кассир-вампир, который «вбивает» заказ (анимация на добавл./удал.).
## Замораживает игрока (EventBus.ui_modal). Открывает StallPOI._on_interact(self).

const STALL_EMOJI := {
	"fastfood": "🍔", "mex": "🌮", "asia": "🍜", "veg": "🥗", "coffee": "☕",
}

var _stall: StallPOI
var _sel: Array = []           # выбранные блюда (dish-словари)
var _order_list: VBoxContainer
var _total_label: Label
var _order_btn: Button
var _cashier_face: Label
var _register: Label
var _cashier_say: Label

func _ready() -> void:
	add_to_group("stall_menu")
	visible = false

func open(stall: StallPOI) -> void:
	_stall = stall
	_sel = []
	_build_frame()
	_update_order()
	visible = true
	EventBus.ui_modal.emit(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _close() -> void:
	visible = false
	EventBus.ui_modal.emit(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

# --- Каркас меню (строится один раз при открытии) ---
func _build_frame() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var sid := _stall.stall_id
	var col := FoodMenu.stall_color(sid)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var title := Label.new()
	title.add_theme_font_size_override("font_size", 30)
	title.modulate = col.lightened(0.4)
	title.text = "%s  %s" % [STALL_EMOJI.get(sid, "🍽"), FoodMenu.stall_name(sid)]
	root.add_child(title)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	root.add_child(cols)

	# ---- Колонка 1: МЕНЮ ----
	var menu_col := VBoxContainer.new()
	menu_col.custom_minimum_size = Vector2(420, 460)
	cols.add_child(menu_col)
	menu_col.add_child(_head("МЕНЮ", col.lightened(0.4)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for d in FoodMenu.dishes(sid):
		list.add_child(_dish_card(d, sid, col))

	# ---- Колонка 2: ВАШ ЗАКАЗ ----
	var order_col := VBoxContainer.new()
	order_col.custom_minimum_size = Vector2(300, 460)
	cols.add_child(order_col)
	order_col.add_child(_head("ВАШ ЗАКАЗ", Color(1, 0.9, 0.5)))
	var oscroll := ScrollContainer.new()
	oscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	oscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	order_col.add_child(oscroll)
	_order_list = VBoxContainer.new()
	_order_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_order_list.add_theme_constant_override("separation", 6)
	oscroll.add_child(_order_list)
	_total_label = Label.new()
	_total_label.add_theme_font_size_override("font_size", 18)
	_total_label.modulate = Color(1, 0.9, 0.4)
	order_col.add_child(_total_label)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	order_col.add_child(actions)
	var clear_btn := Button.new()
	clear_btn.text = "Очистить"
	clear_btn.pressed.connect(_on_clear)
	actions.add_child(clear_btn)
	_order_btn = Button.new()
	_order_btn.text = "Заказать"
	_order_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_order_btn.pressed.connect(_on_order)
	actions.add_child(_order_btn)
	var cancel_btn := Button.new()
	cancel_btn.text = "Esc"
	cancel_btn.pressed.connect(_close)
	actions.add_child(cancel_btn)

	# ---- Колонка 3: КАССА (кассир-вампир) ----
	cols.add_child(_build_cashier())

func _head(text: String, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 20)
	l.modulate = color
	l.text = text
	return l

# Карточка блюда: иконка + название/цена + лор-описание + баф/дебаф + статы + «в заказ».
func _dish_card(d: Dictionary, sid: String, col: Color) -> PanelContainer:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.12, 0.16, 0.95)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	sb.border_width_left = 5
	sb.border_color = col
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	card.add_child(h)

	# Иконка-«картинка» блюда (плашка цвета лавки + эмодзи).
	var pic_sb := StyleBoxFlat.new()
	pic_sb.bg_color = col.darkened(0.1)
	pic_sb.set_corner_radius_all(8)
	var pic := PanelContainer.new()
	pic.add_theme_stylebox_override("panel", pic_sb)
	pic.custom_minimum_size = Vector2(66, 66)
	var picc := CenterContainer.new()
	pic.add_child(picc)
	var emoji := Label.new()
	emoji.add_theme_font_size_override("font_size", 34)
	emoji.text = STALL_EMOJI.get(sid, "🍽")
	picc.add_child(emoji)
	h.add_child(pic)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	h.add_child(info)
	var nm := Label.new()
	nm.add_theme_font_size_override("font_size", 16)
	nm.text = "%s — %d мон." % [str(d["name"]), int(d["price"])]
	info.add_child(nm)
	var desc := Label.new()
	desc.add_theme_font_size_override("font_size", 12)
	desc.modulate = Color(0.78, 0.74, 0.82)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 250
	desc.text = str(d.get("desc", ""))
	info.add_child(desc)
	var eff_text := FoodMenu.effect_label(sid)
	if eff_text != "":
		var eff := Label.new()
		eff.add_theme_font_size_override("font_size", 12)
		eff.modulate = Color(1.0, 0.55, 0.4) if FoodMenu.effect_is_debuff(sid) else Color(0.5, 0.95, 0.6)
		eff.text = eff_text
		info.add_child(eff)
	var stats := Label.new()
	stats.add_theme_font_size_override("font_size", 12)
	stats.modulate = Color(0.7, 0.75, 0.85)
	stats.text = FoodMenu.dish_stats(d)
	info.add_child(stats)

	var add_btn := Button.new()
	add_btn.text = "＋"
	add_btn.add_theme_font_size_override("font_size", 22)
	add_btn.custom_minimum_size = Vector2(44, 0)
	add_btn.pressed.connect(_on_add.bind(d))
	h.add_child(add_btn)
	return card

func _build_cashier() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(210, 460)
	box.add_child(_head("КАССА", Color(0.85, 0.7, 1.0)))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.08, 0.14, 0.95)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", sb)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(panel)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	_cashier_face = Label.new()
	_cashier_face.add_theme_font_size_override("font_size", 96)
	_cashier_face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cashier_face.text = "🧛"
	v.add_child(_cashier_face)
	var namel := Label.new()
	namel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	namel.modulate = Color(0.8, 0.8, 0.9)
	namel.text = "Кассир Дракулеску"
	v.add_child(namel)
	_register = Label.new()
	_register.add_theme_font_size_override("font_size", 40)
	_register.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_register.text = "🧾"
	v.add_child(_register)
	_cashier_say = Label.new()
	_cashier_say.add_theme_font_size_override("font_size", 14)
	_cashier_say.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cashier_say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cashier_say.custom_minimum_size.x = 180
	_cashier_say.modulate = Color(0.7, 0.95, 0.8)
	_cashier_say.text = "Что желаете, голубчик?"
	v.add_child(_cashier_say)
	return box

# Кассир «вбивает» заказ: пунч кассы + кивок головы + реплика.
func _cashier_react(added: bool) -> void:
	if _register == null:
		return
	_register.pivot_offset = _register.size * 0.5
	_register.scale = Vector2(1.35, 1.35)
	_register.modulate = Color(1.0, 0.9, 0.4)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_register, "scale", Vector2.ONE, 0.28)
	tw.parallel().tween_property(_register, "modulate", Color.WHITE, 0.28)
	_cashier_face.pivot_offset = _cashier_face.size * 0.5
	_cashier_face.scale = Vector2(1.0, 0.88)   # кивок
	var tw2 := create_tween()
	tw2.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw2.tween_property(_cashier_face, "scale", Vector2.ONE, 0.2)
	var add_lines := ["*тык-тык* вношу…", "Записал, кровопийца.", "Ещё что-нибудь?", "*клац-клац*"]
	var rem_lines := ["Убираю позицию…", "Передумали? Бывает.", "*бэкспейс*", "Минус один."]
	_cashier_say.text = (add_lines if added else rem_lines).pick_random()

# --- Заказ ---
func _on_add(d: Dictionary) -> void:
	_sel.append(d)
	_update_order()
	_cashier_react(true)

func _on_remove(idx: int) -> void:
	if idx >= 0 and idx < _sel.size():
		_sel.remove_at(idx)
		_update_order()
		_cashier_react(false)

func _on_clear() -> void:
	if _sel.is_empty():
		return
	_sel.clear()
	_update_order()
	_cashier_react(false)

func _update_order() -> void:
	for c in _order_list.get_children():
		c.queue_free()
	var total := 0
	for i in _sel.size():
		var d: Dictionary = _sel[i]
		total += int(d["price"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_order_list.add_child(row)
		var nm := Label.new()
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.text = "%s" % str(d["name"])
		row.add_child(nm)
		var price := Label.new()
		price.text = "%d" % int(d["price"])
		price.modulate = Color(1, 0.9, 0.5)
		row.add_child(price)
		var rm := Button.new()
		rm.text = "−"
		rm.add_theme_font_size_override("font_size", 18)
		rm.pressed.connect(_on_remove.bind(i))
		row.add_child(rm)
	if _sel.is_empty():
		var empty := Label.new()
		empty.modulate = Color(0.6, 0.6, 0.66)
		empty.text = "Пусто — выбирайте слева."
		_order_list.add_child(empty)
	_total_label.text = "Итого: %d монет\nУ вас: %d" % [total, RunState.coins]
	var enough := total > 0 and RunState.coins >= total
	_order_btn.disabled = not enough

func _on_order() -> void:
	if _sel.is_empty():
		EventBus.toast.emit("Выберите хотя бы одно блюдо.")
		return
	var t := 0
	for d in _sel:
		t += int(d["price"])
	if RunState.coins < t:
		EventBus.toast.emit("Не хватает монет: нужно %d." % t)
		return
	RunState.coins -= t
	_stall.place_order(_sel)
	if _cashier_say != null:
		_cashier_say.text = "Ждите пищалку. Приятного… аппетита."
	_close()
