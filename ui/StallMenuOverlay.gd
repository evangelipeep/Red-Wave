extends CanvasLayer
## Меню заказа в лавке: выбрать блюда (можно несколько), увидеть сумму, оплатить и заказать.
## Замораживает игрока через EventBus.ui_modal. Открывается StallPOI._on_interact(self).

var _stall: StallPOI
var _sel: Array = []          # выбранные блюда (dish-словари из FoodMenu)
var _total_label: Label

func _ready() -> void:
	add_to_group("stall_menu")
	visible = false

func open(stall: StallPOI) -> void:
	_stall = stall
	_sel = []
	_build()
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

func _build() -> void:
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
		margin.add_theme_constant_override("margin_" + side, 26)
	panel.add_child(margin)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(460, 0)
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)

	var title := Label.new()
	title.add_theme_font_size_override("font_size", 28)
	title.modulate = col.lightened(0.4)
	title.text = "Лавка: %s" % FoodMenu.stall_name(sid)
	v.add_child(title)

	for d in FoodMenu.dishes(sid):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		v.add_child(row)
		var nm := Label.new()
		nm.text = "%s — %d мон." % [str(d["name"]), int(d["price"])]
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		var add_btn := Button.new()
		add_btn.text = "＋"
		add_btn.pressed.connect(_on_add.bind(d))
		row.add_child(add_btn)

	_total_label = Label.new()
	_total_label.modulate = Color(1, 0.9, 0.4)
	v.add_child(_total_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	v.add_child(actions)
	var clear_btn := Button.new()
	clear_btn.text = "Очистить"
	clear_btn.pressed.connect(_on_clear)
	actions.add_child(clear_btn)
	var order_btn := Button.new()
	order_btn.text = "Заказать"
	order_btn.pressed.connect(_on_order)
	actions.add_child(order_btn)
	var cancel_btn := Button.new()
	cancel_btn.text = "Отмена (Esc)"
	cancel_btn.pressed.connect(_close)
	actions.add_child(cancel_btn)
	_update_total()

func _on_add(d: Dictionary) -> void:
	_sel.append(d)
	_update_total()

func _on_clear() -> void:
	_sel.clear()
	_update_total()

func _update_total() -> void:
	var t := 0
	var counts: Dictionary = {}
	for d in _sel:
		t += int(d["price"])
		counts[d["name"]] = int(counts.get(d["name"], 0)) + 1
	var parts: Array = []
	for k in counts:
		parts.append("%s×%d" % [str(k), int(counts[k])])
	var sel_text := ", ".join(parts) if not parts.is_empty() else "ничего"
	_total_label.text = "Выбрано: %s\nСумма: %d монет (у вас %d)" % [sel_text, t, RunState.coins]

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
	_close()
