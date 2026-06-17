extends Node
## Узел-координатор фуд-корта: обрабатывает выброс (G) и подбор (E) еды.
##   • G у мусорки (группа food_trash) → диалог подтверждения → уничтожить поднос.
##   • G не у мусорки → оставить поднос на полу (DroppedFood) — подбираемо другими.
##   • E рядом с выброшенной едой → подобрать в инвентарь (если есть место).
## Лавки (StallPOI) свой E обрабатывают сами. Сеть/синхрон выброшенной еды — этап 5.

const PICK_R := 2.6     # радиус подбора еды
const TRASH_R := 3.4    # радиус «у мусорки»

func _ready() -> void:
	EventBus.throw_food_pressed.connect(_on_throw)
	EventBus.interact_pressed.connect(_on_interact)

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
