extends Node
## Узел-координатор фуд-корта: обрабатывает выброс (G) и подбор (E) еды.
##   • G у мусорки (группа food_trash) → диалог подтверждения → уничтожить поднос.
##   • G не у мусорки → оставить поднос на полу (DroppedFood) — подбираемо другими.
##   • E рядом с выброшенной едой → подобрать в инвентарь (если есть место).
## Лавки (StallPOI) свой E обрабатывают сами. Сеть/синхрон выброшенной еды — этап 5.

const PICK_R := 2.6     # радиус подбора еды
const TRASH_R := 3.4    # радиус «у мусорки»
const PATRON_CAP := 12  # максимум NPC-посетителей фуд-корта одновременно
const SPAWN_EVERY := 2.5
const MAX_QUEUE := 5    # потолок целевой длины очереди

var stall_hype: Dictionary = {}   # stall_id -> 20..99 (скрытая популярность дня)
var _rush: Dictionary = {}        # stall_id -> доля дня пика спроса
var _spawn_accum := 0.0

func _ready() -> void:
	EventBus.throw_food_pressed.connect(_on_throw)
	EventBus.interact_pressed.connect(_on_interact)
	EventBus.run_started.connect(_roll_hype)

# --- Скрытая популярность лавок (как Гул горок), у каждой свой час пик. ---
func _roll_hype() -> void:
	stall_hype.clear()
	_rush.clear()
	for sid in FoodMenu.ids():
		stall_hype[sid] = randi_range(20, 99)
		_rush[sid] = randf()
	print("[Food] популярность лавок: %s" % str(stall_hype))
	_spawn_cleaner()

func _spawn_cleaner() -> void:
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
		if not tray.is_empty():
			_spawn_dropped(tray, p.global_position)
			EventBus.toast.emit("Поднос оставлен на полу (можно подобрать).")

func _on_interact() -> void:
	var p := _player()
	if p == null or not RunState.can_take_tray():
		return
	var best: Node3D = null
	var bd := PICK_R
	for d in get_tree().get_nodes_in_group("dropped_food"):
		var node := d as Node3D
		var dist := node.global_position.distance_to(p.global_position)
		if dist <= bd:
			bd = dist
			best = node
	if best != null and RunState.add_tray(best.tray):
		best.queue_free()
		EventBus.toast.emit("Поднос подобран.")

func _near_trash(p: Node3D) -> bool:
	for t in get_tree().get_nodes_in_group("food_trash"):
		if (t as Node3D).global_position.distance_to(p.global_position) <= TRASH_R:
			return true
	return false

func _spawn_dropped(tray: Dictionary, pos: Vector3) -> void:
	var f := DroppedFood.new()
	f.setup(tray)
	get_tree().current_scene.add_child(f)
	f.global_position = pos + Vector3(0, 0.1, 0)
