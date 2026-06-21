extends CanvasLayer
## Приветственный экран в раздевалке (по prep_started): добро пожаловать, главный квест
## («желания дня»), номер шкафчика, подсказки. Закрывается на Enter/Esc — игрок идёт по
## раздевалке, а войдя в парк через розовые двери, запускает день.

func _ready() -> void:
	add_to_group("welcome_overlay")
	visible = false
	EventBus.prep_started.connect(_show_welcome)

func _show_welcome() -> void:
	_build()
	visible = true
	EventBus.ui_modal.emit(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _close() -> void:
	visible = false
	EventBus.ui_modal.emit(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")):
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
		margin.add_theme_constant_override("margin_" + side, 30)
	panel.add_child(margin)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(620, 0)
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)

	var title := Label.new()
	title.add_theme_font_size_override("font_size", 30)
	title.modulate = Color(1.0, 0.6, 0.7)
	title.text = "Добро пожаловать в аквапарк «Красная Река»!"
	v.add_child(title)

	var sub := Label.new()
	sub.text = "Сегодня вы пришли с такими желаниями:"
	v.add_child(sub)

	if RunState.main_quest.is_empty():
		var wait := Label.new()
		wait.modulate = Color(0.8, 0.85, 0.95)
		wait.text = "   (ждём начала дня от хоста…)"
		v.add_child(wait)
	else:
		for a in RunState.main_quest:
			var q := Label.new()
			q.modulate = Color(1.0, 0.92, 0.5)
			q.text = "   • %s" % str((a as Dictionary).get("name", "?"))
			v.add_child(q)

	var more := Label.new()
	more.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	more.custom_minimum_size = Vector2(620, 0)
	more.text = "Хотите больше желаний? Возьмите чужие на РЕСЕПШН — но за невыполненные доп. " + \
		"желания снимут очки. В раздевалке есть душ, туалет и шкафчики."
	v.add_child(more)

	var locker := Label.new()
	locker.add_theme_font_size_override("font_size", 20)
	locker.modulate = Color(0.6, 0.95, 1.0)
	locker.text = "Ваш шкафчик: № %d  —  храните там вещи." % RunState.locker_number
	v.add_child(locker)

	var win := Label.new()
	win.text = "Победит тот, кто наберёт больше очков. Удачи!"
	v.add_child(win)

	var btn := Button.new()
	btn.text = "В раздевалку (Enter)"
	btn.pressed.connect(_close)
	v.add_child(btn)
