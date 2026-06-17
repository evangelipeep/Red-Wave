extends CanvasLayer
## Лобби при старте: выбор режима — одиночная / создать игру (хост) / подключиться (IP).
## Если режим задан из cmdline (--host/--join/--single), лобби не показывается —
## RunBootstrap стартует сам (для headless-тестов и быстрого запуска).

@onready var _bootstrap: Node = get_tree().current_scene
var _ip_edit: LineEdit
var _status: Label

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--host" in args or "--join" in args or "--single" in args or Net.is_online():
		queue_free()   # режим уже выбран из cmdline — лобби не нужно
		return
	_build_ui()

func _build_ui() -> void:
	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(520, 0)
	v.add_theme_constant_override("separation", 12)
	margin.add_child(v)

	var title := Label.new()
	title.add_theme_font_size_override("font_size", 30)
	title.text = "Красная Волна — выбор режима"
	v.add_child(title)

	var b_single := Button.new()
	b_single.text = "Одиночная игра"
	b_single.pressed.connect(_on_single)
	v.add_child(b_single)

	var b_host := Button.new()
	b_host.text = "Создать игру (хост)"
	b_host.pressed.connect(_on_host)
	v.add_child(b_host)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	v.add_child(hb)
	var b_join := Button.new()
	b_join.text = "Подключиться →"
	b_join.pressed.connect(_on_join)
	hb.add_child(b_join)
	_ip_edit = LineEdit.new()
	_ip_edit.text = "127.0.0.1"
	_ip_edit.custom_minimum_size = Vector2(220, 0)
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(_ip_edit)

	_status = Label.new()
	_status.modulate = Color(1, 0.85, 0.4)
	_status.text = "Порт %d. Хост ждёт игроков, можно начинать день сразу." % Net.PORT
	v.add_child(_status)

func _on_single() -> void:
	_finish()
	_bootstrap.begin_local()

func _on_host() -> void:
	Net.host()
	_finish()
	_bootstrap.begin_local()

func _on_join() -> void:
	var ip := _ip_edit.text.strip_edges()
	if ip.is_empty():
		_status.text = "Введите IP хоста."
		return
	Net.join(ip)
	_finish()
	_bootstrap.begin_remote()

func _finish() -> void:
	queue_free()
