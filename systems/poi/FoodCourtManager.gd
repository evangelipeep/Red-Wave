extends Node
## Узел-координатор фуд-корта: обрабатывает выброс (G) и подбор (E) еды.
##   • G у мусорки (группа food_trash) → диалог подтверждения → уничтожить поднос.
##   • G не у мусорки → оставить поднос на полу (DroppedFood) — подбираемо другими.
##   • E рядом с выброшенной едой → подобрать в инвентарь (если есть место).
## Лавки (StallPOI) свой E обрабатывают сами.
## Кооп (этап 5): популярность лавок одна на всех (хост → клиенты). NPC-патроны —
## локальные у каждого клиента (как NPC горок), но по общей популярности очереди похожи.

const PICK_R := 2.6        # радиус подбора еды
const TRASH_R := 3.4       # радиус «у мусорки»
const PATRON_CAP := 12     # максимум NPC-посетителей фуд-корта одновременно
const SPAWN_EVERY := 2.5
const MAX_QUEUE := 5       # потолок целевой длины очереди
const FALLBACK_FRAC := 30.0 / 720.0   # авто-деспаун бесхозной еды (страховка), 30 игр.мин

var stall_hype: Dictionary = {}   # stall_id -> 20..99 (скрытая популярность дня)
var _rush: Dictionary = {}        # stall_id -> доля дня пика спроса
var _spawn_accum := 0.0
var _dropped: Dictionary = {}     # net_id -> DroppedFood (реестр выброшенной еды)
var _next_id := 1                 # выдаёт хост/одиночка

func _ready() -> void:
	add_to_group("food_court_mgr")
	EventBus.throw_food_pressed.connect(_on_throw)
	EventBus.interact_pressed.connect(_on_interact)
	EventBus.run_started.connect(_roll_hype)
	Net.peer_joined.connect(_on_peer_joined)

# --- Скрытая популярность лавок (как Гул горок), у каждой свой час пик. ---
# Кооп: катит только хост/одиночка; клиент ждёт _sync_hype от хоста.
func _roll_hype() -> void:
	_spawn_cleaner()
	if Net.is_online() and not Net.is_server():
		return
	stall_hype.clear()
	_rush.clear()
	for sid in FoodMenu.ids():
		stall_hype[sid] = randi_range(20, 99)
		_rush[sid] = randf()
	print("[Food] популярность лавок: %s" % str(stall_hype))
	if Net.is_online() and Net.is_server():
		rpc("_sync_hype", stall_hype, _rush)

# Новый игрок подключился — хост шлёт ему текущую популярность.
func _on_peer_joined(_id: int) -> void:
	if Net.is_online() and Net.is_server() and not stall_hype.is_empty():
		rpc("_sync_hype", stall_hype, _rush)

@rpc("authority", "reliable", "call_remote")
func _sync_hype(hype: Dictionary, rush: Dictionary) -> void:
	stall_hype = hype
	_rush = rush
	print("[Food] популярность лавок от хоста: %s" % str(stall_hype))

func _spawn_cleaner() -> void:
	if Net.is_online() and not Net.is_server():
		return   # в коопе уборку ведёт хост (синхрон удаления еды)
	if not get_tree().get_nodes_in_group("cleaner").is_empty():
		return
	var trash := get_tree().get_first_node_in_group("food_trash")
	if trash == null:
		return
	var c := Cleaner.new()
	get_tree().current_scene.add_child(c)
	c.global_position = (trash as Node3D).global_position + Vector3(1.5, 0.2, 1.5)

func _process(delta: float) -> void:
	if not Clock.running:
		return
	_spawn_accum += delta
	if _spawn_accum >= SPAWN_EVERY:
		_spawn_accum = 0.0
		_spawn_tick()
	# Страховочный деспаун бесхозной еды (ведёт хост/одиночка; уборщик убирает раньше).
	if (not Net.is_online()) or Net.is_server():
		var t := Clock.day_fraction
		for id in _dropped.keys():
			var f = _dropped[id]
			if is_instance_valid(f) and t - float(f.spawned_at) >= FALLBACK_FRAC:
				remove_dropped(int(id))

# Целевая длина очереди лавки = популярность × час-пик × фаза дня (0..MAX_QUEUE).
func _target_len(sid: String) -> int:
	var base := float(stall_hype.get(sid, 50)) / 99.0
	var rush := 0.5 + 0.5 * cos(TAU * (Clock.day_fraction - float(_rush.get(sid, 0.5))))
	var phase := Clock.queue_phase_multiplier()
	return int(round(base * rush * phase * float(MAX_QUEUE)))

# Подкидываем по одному патрону к лавке с наибольшим дефицитом очереди (оптимизация:
# не симулируем сотни NPC — держим целевую длину очередей).
func _spawn_tick() -> void:
	if get_tree().get_nodes_in_group("food_patron").size() >= PATRON_CAP:
		return
	var best: StallPOI = null
	var best_deficit := 0
	for s in get_tree().get_nodes_in_group("stall"):
		var stall := s as StallPOI
		var deficit := _target_len(stall.stall_id) - stall.queue_len()
		if deficit > best_deficit:
			best_deficit = deficit
			best = stall
	if best != null:
		_spawn_patron(best)

func _spawn_patron(stall: StallPOI) -> void:
	var p := FoodPatron.new()
	get_tree().current_scene.add_child(p)
	p.global_position = stall.global_position + Vector3(randf_range(-4, 4), 0.2, 14)
	p.setup(stall)

func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D

func _on_throw() -> void:
	if RunState.selected_slot < 0:
		return
	if RunState.selected_slot >= RunState.trays.size():
		return   # активен слот предмета (таблетка/пистолет), а не поднос
	var p := _player()
	if p == null:
		return
	var slot := RunState.selected_slot
	if _near_trash(p):
		var dlg := get_tree().get_first_node_in_group("confirm_dialog")
		if dlg != null:
			dlg.ask("Вы точно не хотите доесть и выбросить поднос в мусор?",
				func() -> void:
					RunState.trash_tray(slot)
					EventBus.toast.emit("Поднос выброшен в мусор."))
	else:
		var tray := RunState.drop_tray(slot)
		if tray.is_empty():
			return
		var pos := p.global_position + Vector3(0, 0.1, 0)
		if not Net.is_online():
			_make_dropped(_next_id, tray["stall_id"], tray["dishes"], tray["color"], pos)
			_next_id += 1
		elif Net.is_server():
			_host_spawn_dropped(tray["stall_id"], tray["dishes"], tray["color"], pos)
		else:
			rpc_id(1, "_req_drop", tray["stall_id"], tray["dishes"], tray["color"], pos)
		EventBus.toast.emit("Поднос оставлен на полу (можно подобрать).")

func _on_interact() -> void:
	var p := _player()
	if p == null or not RunState.can_take_tray():
		return
	var best := _nearest_dropped(p)
	if best == null:
		return
	if not Net.is_online():
		var tray: Dictionary = best.tray
		_destroy(best.net_id)
		RunState.add_tray(tray)
		EventBus.toast.emit("Поднос подобран.")
	elif Net.is_server():
		if _dropped.has(best.net_id):
			rpc("_net_pickup", best.net_id, Net.local_id())   # хост сам раздаёт
	else:
		rpc_id(1, "_req_pickup", best.net_id, Net.local_id())

func _nearest_dropped(p: Node3D) -> DroppedFood:
	var best: DroppedFood = null
	var bd := PICK_R
	for d in get_tree().get_nodes_in_group("dropped_food"):
		var node := d as DroppedFood
		var dist := node.global_position.distance_to(p.global_position)
		if dist <= bd:
			bd = dist
			best = node
	return best

func _near_trash(p: Node3D) -> bool:
	for t in get_tree().get_nodes_in_group("food_trash"):
		if (t as Node3D).global_position.distance_to(p.global_position) <= TRASH_R:
			return true
	return false

# --- Выброшенная еда: сетевая сущность (host-authority спавн/подбор/уборка). ---
func _make_dropped(id: int, stall_id: String, dishes: Array, color: Color, pos: Vector3) -> void:
	var f := DroppedFood.new()
	f.net_id = id
	f.setup({"stall_id": stall_id, "color": color, "dishes": dishes})
	get_tree().current_scene.add_child(f)
	f.global_position = pos
	_dropped[id] = f

func _destroy(id: int) -> void:
	var f = _dropped.get(id)
	if f != null and is_instance_valid(f):
		f.queue_free()
	_dropped.erase(id)

# Публичный (уборщик/деспаун): убрать еду — в коопе через хоста, иначе локально.
func remove_dropped(id: int) -> void:
	if Net.is_online():
		if Net.is_server():
			rpc("_net_remove", id)
	else:
		_destroy(id)

# Хост: выдать id и разослать спавн всем (включая себя, call_local).
func _host_spawn_dropped(stall_id: String, dishes: Array, color: Color, pos: Vector3) -> void:
	var id := _next_id
	_next_id += 1
	rpc("_net_spawn", id, stall_id, dishes, color, pos)

@rpc("any_peer", "reliable", "call_remote")
func _req_drop(stall_id: String, dishes: Array, color: Color, pos: Vector3) -> void:
	if Net.is_server():
		_host_spawn_dropped(stall_id, dishes, color, pos)

@rpc("authority", "reliable", "call_local")
func _net_spawn(id: int, stall_id: String, dishes: Array, color: Color, pos: Vector3) -> void:
	_make_dropped(id, stall_id, dishes, color, pos)

@rpc("any_peer", "reliable", "call_remote")
func _req_pickup(id: int, requester: int) -> void:
	if not Net.is_server() or not _dropped.has(id):
		return
	rpc("_net_pickup", id, requester)

@rpc("authority", "reliable", "call_local")
func _net_pickup(id: int, requester: int) -> void:
	if not _dropped.has(id):
		return
	var tray: Dictionary = _dropped[id].tray
	_destroy(id)
	if requester == Net.local_id():
		RunState.add_tray(tray)
		EventBus.toast.emit("Поднос подобран.")

@rpc("authority", "reliable", "call_local")
func _net_remove(id: int) -> void:
	_destroy(id)
