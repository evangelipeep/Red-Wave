extends CanvasLayer
## Магазин предметов — то же 3-колоночное меню, что у лавки еды:
##   • слева ТОВАРЫ: карточки (иконка, лор-описание в вампирском юморе, эффект, цена, «＋»);
##   • по центру КОРЗИНА: выбранное (можно убрать) + сумма + «Купить»;
##   • справа КАССА: кассир-вампир (CashierWidget) «вбивает» покупку.
## Продаёт: водяной пистолет, таблетки от тошноты, сувенир. Открывает ItemShopPOI.

const SOUVENIR_ID := "shop_central"
const SOUVENIR_COST := 2

var _cart: Array = []          # выбранные товары (catalog-словари)
var _order_list: VBoxContainer
var _total_label: Label
var _buy_btn: Button
var _cashier: CashierWidget

func _ready() -> void:
	add_to_group("item_shop_menu")
	visible = false

func _catalog() -> Array:
	return [
		{"id": "gun", "name": "Водяной пистолет", "price": GameConstants.GUN_COST, "icon": "🔫",
			"desc": "Брызгает ледяной водой — отбрасывает зазевавшихся гостей и комаров-NPC. Чистое веселье.",
			"effect": "ПКМ — толкает игроков и NPC.", "owned": RunState.has_gun},
		{"id": "pill", "name": "Таблетка от тошноты", "price": GameConstants.PILL_COST, "icon": "💊",
			"desc": "Горькая пилюля от качки. Глотнул — и карусель в башке замерла.",
			"effect": "Снимает тошноту в 0 (клавиша H).", "owned": false},
		{"id": "souvenir", "name": "Сувенир «Красная Река»", "price": SOUVENIR_COST, "icon": "🎏",
			"desc": "Брелок-комарик на память. Доказательство, что ты тут был и (главное) выжил.",
			"effect": "В коллекцию сувениров (квест).", "owned": RunState.souvenirs.has(SOUVENIR_ID)},
	]

func open() -> void:
	_cart = []
	_build_frame()
	_update_cart()
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

func _build_frame() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var accent := Color(0.6, 0.9, 0.95)
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
	title.modulate = accent
	title.text = "🛒  Магазин"
	root.add_child(title)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	root.add_child(cols)

	# Колонка 1 — товары.
	var goods := VBoxContainer.new()
	goods.custom_minimum_size = Vector2(420, 420)
	cols.add_child(goods)
	goods.add_child(_head("ТОВАРЫ", accent))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	goods.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for item in _catalog():
		list.add_child(_item_card(item, accent))

	# Колонка 2 — корзина.
	var cart_col := VBoxContainer.new()
	cart_col.custom_minimum_size = Vector2(300, 420)
	cols.add_child(cart_col)
	cart_col.add_child(_head("КОРЗИНА", Color(1, 0.9, 0.5)))
	var oscroll := ScrollContainer.new()
	oscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	oscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cart_col.add_child(oscroll)
	_order_list = VBoxContainer.new()
	_order_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_order_list.add_theme_constant_override("separation", 6)
	oscroll.add_child(_order_list)
	_total_label = Label.new()
	_total_label.add_theme_font_size_override("font_size", 18)
	_total_label.modulate = Color(1, 0.9, 0.4)
	cart_col.add_child(_total_label)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	cart_col.add_child(actions)
	var clear_btn := Button.new()
	clear_btn.text = "Очистить"
	clear_btn.pressed.connect(_on_clear)
	actions.add_child(clear_btn)
	_buy_btn = Button.new()
	_buy_btn.text = "Купить"
	_buy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buy_btn.pressed.connect(_on_buy)
	actions.add_child(_buy_btn)
	var cancel_btn := Button.new()
	cancel_btn.text = "Esc"
	cancel_btn.pressed.connect(_close)
	actions.add_child(cancel_btn)

	# Колонка 3 — кассир.
	_cashier = CashierWidget.new()
	_cashier.clerk_name = "Продавец Носферату"
	cols.add_child(_cashier)

func _head(text: String, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 20)
	l.modulate = color
	l.text = text
	return l

func _item_card(item: Dictionary, accent: Color) -> PanelContainer:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.12, 0.16, 0.95)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	sb.border_width_left = 5
	sb.border_color = accent
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	card.add_child(h)

	var pic_sb := StyleBoxFlat.new()
	pic_sb.bg_color = accent.darkened(0.45)
	pic_sb.set_corner_radius_all(8)
	var pic := PanelContainer.new()
	pic.add_theme_stylebox_override("panel", pic_sb)
	pic.custom_minimum_size = Vector2(66, 66)
	var picc := CenterContainer.new()
	pic.add_child(picc)
	var emoji := Label.new()
	emoji.add_theme_font_size_override("font_size", 34)
	emoji.text = str(item["icon"])
	picc.add_child(emoji)
	h.add_child(pic)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	h.add_child(info)
	var nm := Label.new()
	nm.add_theme_font_size_override("font_size", 16)
	nm.text = "%s — %d мон." % [str(item["name"]), int(item["price"])]
	info.add_child(nm)
	var desc := Label.new()
	desc.add_theme_font_size_override("font_size", 12)
	desc.modulate = Color(0.78, 0.74, 0.82)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 250
	desc.text = str(item["desc"])
	info.add_child(desc)
	var eff := Label.new()
	eff.add_theme_font_size_override("font_size", 12)
	eff.modulate = Color(0.5, 0.95, 0.6)
	eff.text = str(item["effect"])
	info.add_child(eff)

	var add_btn := Button.new()
	add_btn.add_theme_font_size_override("font_size", 22)
	add_btn.custom_minimum_size = Vector2(44, 0)
	var sold_out: bool = bool(item.get("owned", false)) or _in_cart(item["id"]) and item["id"] != "pill"
	if bool(item.get("owned", false)):
		add_btn.text = "✓"
		add_btn.disabled = true
		nm.text += "  (есть)"
	elif sold_out:
		add_btn.text = "✓"
		add_btn.disabled = true
	else:
		add_btn.text = "＋"
		add_btn.pressed.connect(_on_add.bind(item))
	h.add_child(add_btn)
	return card

func _in_cart(item_id: String) -> bool:
	for it in _cart:
		if it["id"] == item_id:
			return true
	return false

func _on_add(item: Dictionary) -> void:
	# Пистолет и сувенир — по одному; таблетки — сколько угодно.
	if item["id"] != "pill" and _in_cart(item["id"]):
		return
	_cart.append(item)
	_build_frame()   # перерисовать карточки (кнопки доступности) + корзину
	_update_cart()
	_cashier.react(true)

func _on_remove(idx: int) -> void:
	if idx >= 0 and idx < _cart.size():
		_cart.remove_at(idx)
		_build_frame()
		_update_cart()
		_cashier.react(false)

func _on_clear() -> void:
	if _cart.is_empty():
		return
	_cart.clear()
	_build_frame()
	_update_cart()
	_cashier.react(false)

func _update_cart() -> void:
	for c in _order_list.get_children():
		c.queue_free()
	var total := 0
	for i in _cart.size():
		var it: Dictionary = _cart[i]
		total += int(it["price"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_order_list.add_child(row)
		var nm := Label.new()
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.text = "%s %s" % [str(it["icon"]), str(it["name"])]
		row.add_child(nm)
		var price := Label.new()
		price.text = "%d" % int(it["price"])
		price.modulate = Color(1, 0.9, 0.5)
		row.add_child(price)
		var rm := Button.new()
		rm.text = "−"
		rm.add_theme_font_size_override("font_size", 18)
		rm.pressed.connect(_on_remove.bind(i))
		row.add_child(rm)
	if _cart.is_empty():
		var empty := Label.new()
		empty.modulate = Color(0.6, 0.6, 0.66)
		empty.text = "Пусто — выбирайте слева."
		_order_list.add_child(empty)
	_total_label.text = "Итого: %d монет\nУ вас: %d" % [total, RunState.coins]
	_buy_btn.disabled = total <= 0 or RunState.coins < total

func _on_buy() -> void:
	if _cart.is_empty():
		return
	var total := 0
	for it in _cart:
		total += int(it["price"])
	if RunState.coins < total:
		EventBus.toast.emit("Не хватает монет: нужно %d." % total)
		return
	RunState.coins -= total
	var bought := 0
	for it in _cart:
		match str(it["id"]):
			"gun": RunState.has_gun = true
			"pill": RunState.pills += 1
			"souvenir": RunState.souvenirs[SOUVENIR_ID] = true
		bought += 1
	EventBus.toast.emit("Куплено товаров: %d (−%d монет)." % [bought, total])
	_cashier.say("Спасибо за покупку! Не кусайтесь.")
	_close()
