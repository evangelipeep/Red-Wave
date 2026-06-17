extends CanvasLayer
## Модальный диалог «Да/Нет» (выброс еды в мусорку). Замораживает игрока (ui_modal).
## Вызов: get_first_node_in_group("confirm_dialog").ask(text, Callable).

var _on_yes: Callable

func _ready() -> void:
	add_to_group("confirm_dialog")
	visible = false

func ask(text: String, on_yes: Callable) -> void:
	_on_yes = on_yes
	_build(text)
	visible = true
	EventBus.ui_modal.emit(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _build(text: String) -> void:
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
	v.custom_minimum_size = Vector2(420, 0)
	v.add_theme_constant_override("separation", 14)
	margin.add_child(v)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(label)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(actions)
	var yes := Button.new()
	yes.text = "Да, выбросить"
	yes.pressed.connect(_yes)
	actions.add_child(yes)
	var no := Button.new()
	no.text = "Нет (Esc)"
	no.pressed.connect(_close)
	actions.add_child(no)

func _yes() -> void:
	var cb := _on_yes
	_close()
	if cb.is_valid():
		cb.call()

func _close() -> void:
	visible = false
	EventBus.ui_modal.emit(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
