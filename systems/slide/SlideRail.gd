extends Node3D
class_name SlideRail
## Горка с НАЗЕМНЫМ стартом: посадка на земле → спуск по сплайну вниз в бассейн-яму.
## Никакой лестницы наверх — нет телепорта, спуск совпадает с местом посадки.
## Очередь на земле: NPC (с коллизией) и игрок стоят в линию; кто впереди и слот
## свободен — тот едет. Слот занят весь цикл (пока предыдущий не вылез из бассейна).
## Яму под бассейн горка копает сама в общем полу (узел в группе "ground").

@export var slide_id: String = "klyk"
@export var base_speed: float = 6.0
@export var max_speed: float = 22.0
@export var drag: float = 0.25
@export var build_demo_curve: bool = true
@export var build_access: bool = true

const NPC_RIDE_DURATION := 3.0
const NPC_EXIT_DURATION := 1.5
const OCCUPY_TIMEOUT := 10.0

var _path: Path3D
var _follow: PathFollow3D
var _mount: Area3D
var _rider: PlayerController = null
var _npc_rider: NPCAgent = null
var _npc_phase: int = 0          # 0 — спуск, 1 — вылезание по лесенке
var _speed: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 18.0)

var _npc_queue: Array = []
var _player_waiting: bool = false
var _player_ref: PlayerController = null
var _player_ahead: int = 0
var _player_wait: float = 0.0
var _player_no_wait: bool = false
var _player_legit: bool = false
var _player_turn: bool = false      # очередь подошла (можно идти на посадку легитимно)
var _player_turn_t: float = 0.0
var _was_player_next: bool = false

var _occupied: bool = false
var _occupant: Object = null
var _occupy_t: float = 0.0
var _occ_player_swam: bool = false

var _top_local: Vector3
var _pool_center: Vector3
var _pool_radius: float = 4.5
var _pool_floor_y: float = -3.0
var _pool_surface_y: float = -0.3
var _light_red: MeshInstance3D
var _light_green: MeshInstance3D
var _board_zone: Area3D     # зона посадки (заходишь сюда — едешь)
const BOARD_OFFSET := Vector3(0, 0, 1.5)      # зона ПОСАДКИ на платформе, у устья трубы
const QUEUE_BACK_OFFSET := Vector3(0, 0, 4.5) # зона ОЖИДАНИЯ на платформе, позади посадки

func _ready() -> void:
	add_to_group("slide")
	_setup_path()
	_setup_follow()
	_top_local = _path.curve.get_point_position(0)
	_setup_mount()
	_build_visuals()
	_build_pool()
	_build_ladder()
	_build_light()
	if build_access and build_demo_curve:
		_build_boarding()

func _setup_path() -> void:
	_path = get_node_or_null("Path") as Path3D
	if _path == null:
		_path = Path3D.new()
		_path.name = "Path"
		add_child(_path)
	if _path.curve == null:
		_path.curve = Curve3D.new()
	if build_demo_curve and _path.curve.point_count == 0:
		_build_demo_curve(_path.curve)

func _build_demo_curve(c: Curve3D) -> void:
	# Старт НАВЕРХУ платформы (y≈5) → прямой спуск в видимый бассейн у земли.
	var pts := [
		Vector3(0, 5.0, 0), Vector3(0, 3.5, -4), Vector3(0, 1.0, -9), Vector3(0, -1.8, -14),
	]
	for p in pts:
		c.add_point(p)
	var n := c.point_count
	for i in range(n):
		var prev := c.get_point_position(maxi(i - 1, 0))
		var nxt := c.get_point_position(mini(i + 1, n - 1))
		var tang := (nxt - prev) * 0.25
		c.set_point_in(i, -tang)
		c.set_point_out(i, tang)

func _setup_follow() -> void:
	_follow = PathFollow3D.new()
	_follow.name = "Follow"
	_follow.rotation_mode = PathFollow3D.ROTATION_ORIENTED
	_follow.loop = false
	_path.add_child(_follow)

func _setup_mount() -> void:
	# Зона ОЖИДАНИЯ (стой здесь, чтобы быть в очереди) — позади посадки.
	_mount = Area3D.new()
	_mount.name = "QueueZone"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(7, 3, 6)
	cs.shape = box
	_mount.add_child(cs)
	add_child(_mount)
	_mount.global_position = to_global(_top_local + QUEUE_BACK_OFFSET)
	_mount.body_entered.connect(_on_mount_body_entered)
	_mount.body_exited.connect(_on_mount_body_exited)

	# Зона ПОСАДКИ (зашёл — поехал) — у самого старта горки.
	_board_zone = Area3D.new()
	_board_zone.name = "BoardZone"
	var bcs := CollisionShape3D.new()
	var bbox := BoxShape3D.new()
	bbox.size = Vector3(3, 3, 2.5)
	bcs.shape = bbox
	_board_zone.add_child(bcs)
	add_child(_board_zone)
	_board_zone.global_position = to_global(_top_local + BOARD_OFFSET)
	_board_zone.body_entered.connect(_on_board_entered)

func board_point() -> Vector3:
	return to_global(_top_local + BOARD_OFFSET)

func _build_boarding() -> void:
	# Платформа наверху (старт сплайна на ней).
	var plat := CSGBox3D.new()
	plat.name = "Platform"
	plat.size = Vector3(10, 0.4, 11)
	plat.use_collision = true
	plat.position = Vector3(_top_local.x, _top_local.y - 0.2, _top_local.z + 4.0)
	plat.material = _make_material(Color(0.55, 0.55, 0.62), false)
	add_child(plat)

	# Пандус-лестница с земли на платформу (проходимая коллизия + визуальные ступени).
	var base := Vector3(_top_local.x, 0.0, _top_local.z + 17.0)
	var top := Vector3(_top_local.x, _top_local.y, _top_local.z + 8.0)
	var ramp := CSGBox3D.new()
	ramp.name = "Ramp"
	ramp.size = Vector3(10, 0.4, base.distance_to(top) + 0.5)
	ramp.use_collision = true
	ramp.material = _make_material(Color(0.6, 0.55, 0.5), false)
	ramp.transform = Transform3D(Basis.looking_at((top - base).normalized(), Vector3.UP), (base + top) * 0.5)
	add_child(ramp)
	var steps := 9
	for i in range(steps):
		var sp := base.lerp(top, float(i) / float(steps - 1))
		var st := CSGBox3D.new()
		st.size = Vector3(10, 0.18, 0.5)
		st.position = sp + Vector3(0, 0.22, 0)
		st.material = _make_material(Color(0.48, 0.44, 0.4), false)
		add_child(st)

	# Маркеры зон: где стоять и где садиться.
	_zone_marker(_top_local + QUEUE_BACK_OFFSET, Color(0.3, 0.5, 1.0, 0.6), "ОЧЕРЕДЬ")
	_zone_marker(_top_local + BOARD_OFFSET, Color(0.3, 1.0, 0.4, 0.6), "ПОСАДКА")

func _zone_marker(local_pos: Vector3, col: Color, text: String) -> void:
	var m := CSGBox3D.new()
	m.size = Vector3(4.5, 0.12, 2.6)
	m.position = local_pos + Vector3(0, 0.08, 0)
	m.material = _make_material(col, true)
	add_child(m)
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.pixel_size = 0.011
	label.outline_size = 8
	label.modulate = col
	label.position = local_pos + Vector3(0, 1.7, 0)
	add_child(label)

func _make_material(col: Color, transparent: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _build_visuals() -> void:
	var tube := CSGPolygon3D.new()
	tube.name = "Tube"
	tube.mode = CSGPolygon3D.MODE_PATH
	tube.polygon = PackedVector2Array([
		Vector2(-1.2, 0.6), Vector2(-1.2, -0.6), Vector2(1.2, -0.6), Vector2(1.2, 0.6),
		Vector2(1.0, 0.6), Vector2(1.0, -0.4), Vector2(-1.0, -0.4), Vector2(-1.0, 0.6),
	])
	tube.path_rotation = CSGPolygon3D.PATH_ROTATION_PATH_FOLLOW
	tube.path_interval = 1.0
	tube.smooth_faces = true
	tube.use_collision = true
	add_child(tube)
	tube.path_node = tube.get_path_to(_path)
	tube.material = _make_material(Color(0.4, 0.7, 1.0, 0.45), true)

	var flow := CSGPolygon3D.new()
	flow.name = "SlideWater"
	flow.mode = CSGPolygon3D.MODE_PATH
	flow.polygon = PackedVector2Array([
		Vector2(-0.95, -0.32), Vector2(-0.95, -0.22),
		Vector2(0.95, -0.22), Vector2(0.95, -0.32),
	])
	flow.path_rotation = CSGPolygon3D.PATH_ROTATION_PATH_FOLLOW
	flow.path_interval = 0.5
	flow.smooth_faces = true
	add_child(flow)
	flow.path_node = flow.get_path_to(_path)
	var sh := load("res://systems/slide/slide_water.gdshader") as Shader
	if sh:
		var sm := ShaderMaterial.new()
		sm.shader = sh
		flow.material = sm

func _build_pool() -> void:
	var end := _path.curve.get_point_position(_path.curve.point_count - 1)
	_pool_center = Vector3(end.x, 0, end.z - 2)

	# Копаем яму в общем полу (узел группы "ground"), если он есть.
	var ground := get_tree().get_first_node_in_group("ground")
	if ground != null:
		var pit := CSGBox3D.new()
		pit.operation = CSGShape3D.OPERATION_SUBTRACTION
		pit.size = Vector3(_pool_radius * 2 + 2, 8, _pool_radius * 2 + 2)
		ground.add_child(pit)
		pit.global_position = to_global(Vector3(_pool_center.x, -2, _pool_center.z))

	# Дно — КВАДРАТНОЕ и крупнее ямы, чтобы NPC/игрок не проваливались в углах.
	var basin := CSGBox3D.new()
	basin.name = "BasinFloor"
	basin.size = Vector3(_pool_radius * 2 + 4, 0.4, _pool_radius * 2 + 4)
	basin.use_collision = true
	basin.position = Vector3(_pool_center.x, _pool_floor_y - 0.2, _pool_center.z)
	add_child(basin)

	var water := MeshInstance3D.new()
	water.name = "Water"
	var cyl := CylinderMesh.new()
	cyl.top_radius = _pool_radius
	cyl.bottom_radius = _pool_radius
	cyl.height = _pool_surface_y - _pool_floor_y
	water.mesh = cyl
	water.position = Vector3(_pool_center.x, (_pool_surface_y + _pool_floor_y) * 0.5, _pool_center.z)
	water.material_override = _make_material(Color(0.8, 0.05, 0.05, 0.7), true)
	add_child(water)

	var area := Area3D.new()
	area.name = "Pool"
	area.add_to_group("water")
	area.set_meta("surface_y", _pool_surface_y)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(_pool_radius * 2, _pool_surface_y - _pool_floor_y + 0.6, _pool_radius * 2)
	cs.shape = box
	area.add_child(cs)
	area.position = Vector3(_pool_center.x, (_pool_surface_y + _pool_floor_y) * 0.5, _pool_center.z)
	add_child(area)

func _build_ladder() -> void:
	var base := _ladder_base_local()
	var top := _ladder_top_local()
	var ramp := CSGBox3D.new()
	ramp.name = "Ladder"
	ramp.size = Vector3(1.4, 0.2, base.distance_to(top) + 0.4)
	ramp.use_collision = true
	ramp.material = _make_material(Color(0.75, 0.7, 0.55), false)
	var dir := (top - base).normalized()
	ramp.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), (base + top) * 0.5)
	add_child(ramp)

func _build_light() -> void:
	var post_local := _top_local + Vector3(-3.0, 1.0, 0)
	_light_red = _light_sphere(Color(1, 0.1, 0.1), post_local + Vector3(0, 0.35, 0))
	_light_green = _light_sphere(Color(0.1, 1, 0.2), post_local)
	_light_green.visible = false

func _light_sphere(col: Color, local_pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.22
	s.height = 0.44
	m.mesh = s
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	m.material_override = mat
	m.position = local_pos
	add_child(m)
	return m

# --- Геометрия для NPC (мир). Очередь на земле, вбок (+X) от посадки. ---
func slot_position(i: int) -> Vector3:
	return to_global(Vector3(2.0 + float(i) * 1.3, _top_local.y, _top_local.z + QUEUE_BACK_OFFSET.z))

func queue_back_position() -> Vector3:
	return slot_position(_npc_queue.size())

func queue_index(agent) -> int:
	return _npc_queue.find(agent)

func join_queue(agent) -> void:
	if not _npc_queue.has(agent):
		_npc_queue.append(agent)

func leave_queue(agent) -> void:
	_npc_queue.erase(agent)

func wander_point() -> Vector3:
	# Гуляют ПЕРЕД платформой (у пандуса), чтобы потом подняться в очередь.
	return to_global(Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(11.0, 20.0)))

func _ladder_base_local() -> Vector3:
	return _pool_center + Vector3(_pool_radius - 0.4, _pool_surface_y, 0)

func _ladder_top_local() -> Vector3:
	return _pool_center + Vector3(_pool_radius + 0.9, 0.4, 0)

func ladder_top() -> Vector3:
	return to_global(_ladder_top_local())

func ride_point(t: float) -> Vector3:
	var baked_len := _path.curve.get_baked_length()
	return _path.to_global(_path.curve.sample_baked(clampf(t, 0.0, 1.0) * baked_len))

# --- Игрок входит/выходит из очереди (зона посадки на земле). ---
func _on_mount_body_entered(body: Node3D) -> void:
	if not (body is PlayerController):
		return
	if _player_waiting or _occupant == body:
		return
	var info: Dictionary = Slides.SLIDES.get(slide_id, {})
	if info.get("extreme", false) and not WeightSystem.can_ride_extreme():
		EventBus.toast.emit("Слишком большой вес (%.0f кг) — на горку не допускаем" % WeightSystem.kg)
		return
	_player_waiting = true
	_player_ref = body
	_player_ahead = _npc_queue.size()
	_player_wait = 0.0

func _on_mount_body_exited(body: Node3D) -> void:
	# Если очередь подошла — выход к посадке не сбрасывает статус.
	if body == _player_ref and not _player_turn:
		_player_waiting = false
		_player_ref = null
		EventBus.queue_update.emit(slide_id, 0, false)

func _physics_process(delta: float) -> void:
	_free_occupancy(delta)
	_update_light()
	if _rider != null:
		_drive_player(delta)
	elif _npc_rider != null:
		_drive_npc(delta)
	elif not _occupied:
		_dispatch()
	if _player_waiting:
		_player_wait += delta
		EventBus.queue_update.emit(slide_id, _player_ahead, true)
	# Ход подошёл, но игрок не сел вовремя — теряет очередь.
	if _player_turn:
		_player_turn_t -= delta
		if _player_turn_t <= 0.0:
			_player_turn = false
			_player_waiting = false
			_player_ref = null
			EventBus.queue_update.emit(slide_id, 0, false)
			EventBus.toast.emit("Очередь подошла, но вы ушли — встаньте заново")

func _free_occupancy(delta: float) -> void:
	if not _occupied:
		return
	_occupy_t += delta
	var done := false
	if _occupant is NPCAgent:
		if (_occupant as NPCAgent).state == NPCAgent.St.WANDER:
			done = true
	elif _occupant is PlayerController:
		if _rider == null:
			var pl := _occupant as PlayerController
			if pl.swimming:
				_occ_player_swam = true
			elif _occ_player_swam:
				done = true
	if _occupy_t > OCCUPY_TIMEOUT:
		done = true
	if done:
		_occupied = false
		_occupant = null
		_occ_player_swam = false

func _dispatch() -> void:
	# Только NPC: на свой ход передний ИДЁТ к посадке (а не телепортируется).
	if _npc_queue.is_empty():
		return
	var front: NPCAgent = _npc_queue[0]
	if front.state == NPCAgent.St.IN_QUEUE:
		_npc_queue.pop_front()
		_occupied = true
		_occupant = front
		_occupy_t = 0.0
		_npc_phase = 0
		front.go_board(board_point())
		if _player_waiting:
			_player_ahead = maxi(_player_ahead - 1, 0)

# NPC дошёл до посадки — поехал.
func npc_board(npc) -> void:
	if _occupant == npc and _npc_rider == null:
		_npc_rider = npc
		_npc_phase = 0
		npc.begin_ride()

# Игрок зашёл в зону посадки — едет (если очередь подошла) или прыгает без очереди.
func _on_board_entered(body: Node3D) -> void:
	if not (body is PlayerController):
		return
	if _occupied or _rider != null or _npc_rider != null:
		EventBus.toast.emit("Занято — подождите")
		return
	var info: Dictionary = Slides.SLIDES.get(slide_id, {})
	if info.get("extreme", false) and not WeightSystem.can_ride_extreme():
		EventBus.toast.emit("Слишком большой вес (%.0f кг) — на горку не допускаем" % WeightSystem.kg)
		return
	if _player_turn:
		_begin_player_ride(body, true)
	elif RunState.queue_jump_banned:
		EventBus.toast.emit("Охранник не пускает без очереди! Встаньте в очередь.")
	else:
		_begin_player_ride(body, false)
		RunState.register_offense()

func _begin_player_ride(p: PlayerController, legit: bool) -> void:
	_player_legit = legit
	_player_no_wait = legit and _player_wait < 4.0
	_player_waiting = false
	_player_turn = false
	_player_ref = null
	_occupied = true
	_occupant = p
	_occupy_t = 0.0
	_occ_player_swam = false
	EventBus.queue_update.emit(slide_id, 0, false)
	_start_ride(p)

func _start_ride(player: PlayerController) -> void:
	_rider = player
	_speed = base_speed
	_follow.progress = 0.0
	_board_zone.monitoring = false
	player.mount_rail(self)

func _drive_player(delta: float) -> void:
	var fwd := -_follow.global_transform.basis.z
	var slope := -fwd.y
	_speed += (_gravity * slope - drag * _speed) * delta
	_speed = clampf(_speed, 1.0, max_speed)
	var eff := _speed * WeightSystem.speed_factor()
	_follow.progress += eff * delta
	_rider.ride_to(_follow.global_transform, clampf(eff / max_speed, 0.0, 1.0), delta)
	if _follow.progress_ratio >= 1.0:
		_finish()

func _drive_npc(delta: float) -> void:
	if _npc_phase == 0:
		_npc_rider.ride_t += delta / NPC_RIDE_DURATION
		var t := clampf(_npc_rider.ride_t, 0.0, 1.0)
		_npc_rider.global_position = ride_point(t)
		if t >= 1.0:
			_npc_rider.begin_exit()
			_npc_phase = 1
	else:
		_npc_rider.ride_t += delta / NPC_EXIT_DURATION
		var t := clampf(_npc_rider.ride_t, 0.0, 1.0)
		_npc_rider.global_position = ride_point(1.0).lerp(ladder_top(), t)
		if t >= 1.0:
			var done := _npc_rider
			_npc_rider = null
			done.end_cycle()

func _update_light() -> void:
	var player_next := _player_waiting and _player_ahead <= 0 and not _occupied \
		and _rider == null and _npc_rider == null
	if _light_green:
		_light_green.visible = player_next
	if _light_red:
		_light_red.visible = not player_next
	if player_next and not _was_player_next:
		_player_turn = true
		_player_turn_t = 12.0
		EventBus.toast.emit("🟢 Ваша очередь — подойдите к посадке!")
	_was_player_next = player_next

func _finish() -> void:
	var rider := _rider
	var exit_vel := (-_follow.global_transform.basis.z) * (_speed * WeightSystem.speed_factor())
	_rider = null
	_speed = 0.0
	rider.dismount(_follow.global_transform, exit_vel)
	EventBus.slide_completed.emit(Net.local_id(), slide_id)
	if _player_legit:
		_player_legit = false
		RunState.register_legit_ride()   # честно отстоял очередь
		if _player_no_wait:
			_player_no_wait = false
			RunState.add_score(GameConstants.NO_LONG_QUEUE_BONUS)
			EventBus.toast.emit("Без очереди! +%d" % GameConstants.NO_LONG_QUEUE_BONUS)
	await get_tree().create_timer(0.8).timeout
	if is_instance_valid(_board_zone):
		_board_zone.monitoring = true
