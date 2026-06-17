extends Node3D
class_name StallPOI
## Лавка фуд-корта: визуал + 3 зоны (ОЧЕРЕДЬ → ЗАКАЗ → ВЫДАЧА), светофор «ваша очередь
## заказывать», меню (StallMenuOverlay), оплата, пищалка-трекер и FIFO-кухня (готовка
## по времени, тем дольше — чем больше заказов впереди).
##
## На фуд-корте очередь НЕ проскочить: нет fast-pass и штрафа — заказ открывается только
## на ЗЕЛЁНЫЙ (впереди никого). Забор готового — в отдельной зоне ВЫДАЧИ, без очереди.
## NPC в очереди и скрытая популярность — этап 4; сеть — этап 5.

@export var stall_id: String = "fastfood"

const ORDER_OFFSET := Vector3(0, 1.5, 3.0)     # встать сюда, чтобы заказать (на зелёный)
const QUEUE_OFFSET := Vector3(0, 1.5, 5.8)     # линия ожидания позади
const PICKUP_OFFSET := Vector3(-3.4, 1.5, 3.0) # зона выдачи (сбоку, без очереди)
const DAY_MINUTES := 720.0                     # день = 12 игр.часов
const COOK_MIN := 5.0                          # базовая готовка (игр.минуты)

var _order_zone: Area3D
var _queue_zone: Area3D
var _pickup_zone: Area3D
var _light_green: MeshInstance3D
var _light_red: MeshInstance3D

var _npc_queue: Array = []      # NPC в очереди заказа (этап 4)
var _order_present := false     # локальный игрок в зоне заказа
var _queue_present := false     # локальный игрок в зоне ожидания
var _pickup_present := false    # локальный игрок в зоне выдачи
var _player_ahead := 0          # NPC впереди игрока (этап 4; пока 0)
var _cook_load := 0             # сколько заказов сейчас готовится (для времени ожидания)
var _was_green := false

func _ready() -> void:
	add_to_group("stall")
	_build_visuals()
	_build_zones()
	_build_light()
	EventBus.interact_pressed.connect(_on_interact)

func _build_visuals() -> void:
	var col := FoodMenu.stall_color(stall_id)
	var body := CSGBox3D.new()
	body.size = Vector3(4.0, 3.0, 2.6)
	body.position = Vector3(0, 1.5, 0)
	body.use_collision = true
	body.material = _mat(col)
	body.add_to_group("navsource")
	add_child(body)
	var counter := CSGBox3D.new()
	counter.size = Vector3(4.4, 0.5, 1.0)
	counter.position = Vector3(0, 1.05, 1.7)
	counter.use_collision = true
	counter.material = _mat(col.lightened(0.3))
	counter.add_to_group("navsource")
	add_child(counter)
	var awning := CSGBox3D.new()
	awning.size = Vector3(4.6, 0.25, 1.6)
	awning.position = Vector3(0, 2.9, 1.6)
	awning.material = _mat(col.darkened(0.2))
	add_child(awning)
	var label := Label3D.new()
	label.text = FoodMenu.stall_name(stall_id)
	label.font_size = 80
	label.pixel_size = 0.02
	label.modulate = col.lightened(0.5)
	label.outline_size = 12
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 3.7, 0)
	add_child(label)

func _build_zones() -> void:
	_queue_zone = _make_zone("StallQueue", QUEUE_OFFSET, Vector3(4, 3, 3))
	_queue_zone.body_entered.connect(func(b: Node3D): if b is PlayerController: _queue_present = true)
	_queue_zone.body_exited.connect(func(b: Node3D): if b is PlayerController: _queue_present = false)
	_order_zone = _make_zone("StallOrder", ORDER_OFFSET, Vector3(3, 3, 2))
	_order_zone.body_entered.connect(func(b: Node3D): if b is PlayerController: _order_present = true)
	_order_zone.body_exited.connect(func(b: Node3D): if b is PlayerController: _order_present = false)
	_pickup_zone = _make_zone("StallPickup", PICKUP_OFFSET, Vector3(2.6, 3, 2.4))
	_pickup_zone.body_entered.connect(func(b: Node3D): if b is PlayerController: _pickup_present = true)
	_pickup_zone.body_exited.connect(func(b: Node3D): if b is PlayerController: _pickup_present = false)
	_zone_marker(ORDER_OFFSET, Color(0.3, 1.0, 0.4, 0.5), "ЗАКАЗ (E)")
	_zone_marker(QUEUE_OFFSET, Color(0.3, 0.5, 1.0, 0.5), "ОЧЕРЕДЬ")
	_zone_marker(PICKUP_OFFSET, Color(1.0, 0.8, 0.3, 0.5), "ВЫДАЧА (E)")

func _make_zone(zone_name: String, offset: Vector3, size: Vector3) -> Area3D:
	var a := Area3D.new()
	a.name = zone_name
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	a.add_child(cs)
	a.position = offset
	add_child(a)
	return a

func _zone_marker(offset: Vector3, col: Color, text: String) -> void:
	var m := CSGBox3D.new()
	m.size = Vector3(2.4, 0.1, 1.8)
	m.position = Vector3(offset.x, 0.06, offset.z)
	m.material = _mat(col, true)
	add_child(m)
	var lb := Label3D.new()
	lb.text = text
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.font_size = 36
	lb.pixel_size = 0.011
	lb.outline_size = 8
	lb.modulate = col
	lb.position = Vector3(offset.x, 1.4, offset.z)
	add_child(lb)

func _build_light() -> void:
	var post := ORDER_OFFSET + Vector3(1.9, 0.4, 0)
	_light_red = _light_sphere(Color(1, 0.1, 0.1), post + Vector3(0, 0.35, 0))
	_light_green = _light_sphere(Color(0.1, 1, 0.2), post)
	_light_green.visible = false

func _light_sphere(col: Color, local_pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.2
	s.height = 0.4
	m.mesh = s
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	m.material_override = mat
	m.position = local_pos
	add_child(m)
	return m

func _process(_delta: float) -> void:
	var green := _order_present and _player_ahead <= 0
	if _light_green:
		_light_green.visible = green
	if _light_red:
		_light_red.visible = not green
	if green and not _was_green and not RunState.has_pending(stall_id):
		EventBus.toast.emit("🟢 %s: можно заказывать (E)" % FoodMenu.stall_name(stall_id))
	_was_green = green

# E — забор готового (в зоне выдачи, без очереди) или заказ (в зоне заказа, на зелёный).
func _on_interact() -> void:
	if _pickup_present and RunState.has_ready_order(stall_id):
		RunState.collect_order(stall_id)
		return
	if not _order_present:
		return
	if RunState.has_pending(stall_id):
		EventBus.toast.emit("Заказ уже принят — заберите его в зоне ВЫДАЧИ.")
		return
	if _player_ahead > 0:
		EventBus.toast.emit("Очередь не проскочить — впереди %d, ждите." % _player_ahead)
		return
	var menu := get_tree().get_first_node_in_group("stall_menu")
	if menu != null:
		menu.open(self)

# Меню зовёт после выбора и списания монет: рассчитываем готовку и выдаём пищалку.
func place_order(order_dishes: Array) -> void:
	var cook_frac := (COOK_MIN / DAY_MINUTES) * float(1 + _cook_load)
	var ready_at := Clock.day_fraction + cook_frac
	_cook_load += 1
	RunState.add_pending_order(stall_id, ready_at, order_dishes)
	# Снять нагрузку кухни, когда заказ должен быть готов (реальные секунды).
	var secs: float = maxf(cook_frac * GameConstants.run_length, 0.1)
	get_tree().create_timer(secs).timeout.connect(func(): _cook_load = maxi(_cook_load - 1, 0))

func _mat(c: Color, transparent: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
