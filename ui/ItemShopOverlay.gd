extends CanvasLayer
## Меню магазина предметов: купить таблетку от тошноты / пистолет-отталкиватель.
## Замораживает игрока (ui_modal). Открывает ItemShopPOI._on_interact.

func _ready() -> void:
	add_to_group("item_shop_menu")
	visible = false

func open() -> void:
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
	title.modulate = Color(0.6, 0.9, 0.95)
	title.text = "Магазин предметов"
	v.add_child(title)

	var status := Label.new()
	status.modulate = Color(1, 0.9, 0.4)
	status.text = "Монеты: %d   ·   Таблетки: %d   ·   Пистолет: %s" % [
		RunState.coins, RunState.pills, ("есть" if RunState.has_gun else "нет")]
	v.add_child(status)

	var b_pill := Button.new()
	b_pill.text = "Таблетка от тошноты (%d мон.) — снимает тошноту в 0" % GameConstants.PILL_COST
	b_pill.pressed.connect(_buy_pill)
	v.add_child(b_pill)

	var b_gun := Button.new()
	b_gun.text = "Пистолет-отталкиватель (%d мон.) — толкать игроков/NPC (ПКМ)" % GameConstants.GUN_COST
	b_gun.disabled = RunState.has_gun
	b_gun.pressed.connect(_buy_gun)
	v.add_child(b_gun)

	var b_close := Button.new()
	b_close.text = "Закрыть (Esc)"
	b_close.pressed.connect(_close)
	v.add_child(b_close)

func _buy_pill() -> void:
	RunState.buy_pill()
	_build()

func _buy_gun() -> void:
	RunState.buy_gun()
	_build()
