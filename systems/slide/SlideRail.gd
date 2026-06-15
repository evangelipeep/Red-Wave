extends Node3D
class_name SlideRail
## Горка: спуск по сплайну + ЖИВАЯ очередь. В очереди стоят NPC и игрок; кто
## впереди — тот катится (по одному за раз). NPC реально съезжают, всплывают,
## вылезают по лестнице и уходят бродить → снова в очередь. Игроку показывает
## светофор: красный — жди, зелёный — «вы следующий». Сделано лёгким (без физики
## у NPC: капсулы двигаются лёрпом по точкам, общий цикл, ограниченное число).

@export var slide_id: String = "klyk"
@export var base_speed: float = 6.0
@export var max_speed: float = 22.0
@export var drag: float = 0.25
@export var build_demo_curve: bool = true
@export var build_access: bool = true

const NPC_RIDE_DURATION := 3.0   # сек на спуск NPC

var _path: Path3D
var _follow: PathFollow3D
var _mount: Area3D
var _rider: PlayerController = null
var _npc_rider: NPCAgent = null
var _speed: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

var _queue: Array = []                       # очередь: NPCAgent или PlayerController
var _player_in_queue: PlayerController = null
var _was_player_next: bool = false

# Геометрия для NPC-запросов.
var _top_local: Vector3
var _pool_center: Vector3
var _pool_radius: float = 4.5
var _pool_floor_y: float = -6.0
var _pool_surface_y: float = -0.1
var _light_red: MeshInstance3D
var _light_green: MeshInstance3D

func _ready() -> void:
	add_to_group("slide")
	_setup_path()
	_setup_follow()
	_setup_mount()
	_top_local = _path.curve.get_point_position(0)
	_build_visuals()
	_build_pool()
	_build_ladder()
	_build_light()
	if build_access and build_demo_curve:
		_build_access_stairs(_top_local)

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
	var pts := [
		Vector3(0, 4.5, 0), Vector3(0, 3.6, -5), Vector3(2.5, 2.6, -9),
		Vector3(2.5, 1.6, -13), Vector3(-1, 0.8, -17), Vector3(0, 0.3, -21),
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
	_mount = Area3D.new()
	_mount.name = "Mount"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 3, 3)
	cs.shape = box
	_mount.add_child(cs)
	add_child(_mount)
	_mount.global_position = _path.to_global(_path.curve.get_point_position(0))
	_mount.body_entered.connect(_on_mount_body_entered)
	_mount.body_exited.connect(_on_mount_body_exited)

func _build_access_stairs(top: Vector3) -> void:
	var steps := 10
	for i in range(steps):
		var f := float(i) / float(steps - 1)
		var step := CSGBox3D.new()
		step.size = Vector3(3, 0.4, 1.2)
		step.use_collision = true
		step.position = Vector3(top.x, top.y * f - 0.2, top.z + float(steps - i) * 1.2)
		add_child(step)
	var plat := CSGBox3D.new()
	plat.name = "TopPlatform"
	plat.size = Vector3(3, 0.4, 2.5)
	plat.use_collision = true
	plat.position = Vector3(top.x, top.y - 0.2, top.z + 0.8)
	add_child(plat)

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
	_pool_center = Vector3(end.x, 0, end.z - 3)

	var basin := CSGCylinder3D.new()
	basin.name = "BasinFloor"
	basin.radius = _pool_radius
	basin.height = 0.4
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
	# Наклонная лесенка из бассейна на бортик (по ней вылезают NPC).
	var base := _ladder_base_local()
	var top := _ladder_top_local()
	var mid := (base + top) * 0.5
	var ramp := CSGBox3D.new()
	ramp.name = "Ladder"
	ramp.size = Vector3(1.4, 0.2, base.distance_to(top) + 0.4)
	ramp.use_collision = true
	ramp.material = _make_material(Color(0.75, 0.7, 0.55), false)
	var dir := (top - base).normalized()
	var basis := Basis.looking_at(dir, Vector3.UP)
	ramp.transform = Transform3D(basis, mid)
	add_child(ramp)

func _build_light() -> void:
	var post_local := _top_local + Vector3(-1.9, 1.4, 1.2)
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

# --- Запросы геометрии для NPC (всё в мировых координатах). ---
func slot_position(i: int) -> Vector3:
	return to_global(_top_local + Vector3(1.8, 0.0, 1.4 + float(i) * 1.2))

func queue_back_position() -> Vector3:
	return slot_position(_queue.size())

func queue_index(agent) -> int:
	return _queue.find(agent)

func join_queue(agent) -> void:
	if not _queue.has(agent):
		_queue.append(agent)

func leave_queue(agent) -> void:
	_queue.erase(agent)

func wander_point() -> Vector3:
	return Vector3(randf_range(-20.0, 20.0), 0.2, randf_range(-8.0, 16.0))

func _ladder_base_local() -> Vector3:
	return _pool_center + Vector3(0, _pool_surface_y, _pool_radius - 0.4)

func _ladder_top_local() -> Vector3:
	return _pool_center + Vector3(0, 0.4, _pool_radius + 0.9)

func ladder_base() -> Vector3:
	return to_global(_ladder_base_local())

func ladder_top() -> Vector3:
	return to_global(_ladder_top_local())

func ride_point(t: float) -> Vector3:
	var baked_len := _path.curve.get_baked_length()
	return _path.to_global(_path.curve.sample_baked(clampf(t, 0.0, 1.0) * baked_len))

# --- Игрок встаёт/выходит из очереди. ---
func _on_mount_body_entered(body: Node3D) -> void:
	if not (body is PlayerController):
		return
	if _player_in_queue == body:
		return
	var info: Dictionary = Slides.SLIDES.get(slide_id, {})
	if info.get("extreme", false) and not WeightSystem.can_ride_extreme():
		EventBus.toast.emit("Слишком большой вес (%.0f кг) — на горку не допускаем" % WeightSystem.kg)
		return
	_player_in_queue = body
	join_queue(body)

func _on_mount_body_exited(body: Node3D) -> void:
	if body == _player_in_queue:
		leave_queue(body)
		_player_in_queue = null
		EventBus.queue_update.emit(slide_id, 0, false)

func _start_ride(player: PlayerController) -> void:
	_rider = player
	_player_in_queue = null
	_speed = base_speed
	_follow.progress = 0.0
	_mount.monitoring = false
	EventBus.queue_update.emit(slide_id, 0, false)
	player.mount_rail(self)

func _physics_process(delta: float) -> void:
	_update_light()   # до диспетча: «вы следующий» успевает показаться
	if _rider != null:
		_drive_player(delta)
	elif _npc_rider != null:
		_drive_npc(delta)
	else:
		_dispatch()
	if _player_in_queue != null:
		EventBus.queue_update.emit(slide_id, queue_index(_player_in_queue), true)

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
	_npc_rider.ride_t += delta / NPC_RIDE_DURATION
	var t := clampf(_npc_rider.ride_t, 0.0, 1.0)
	_npc_rider.global_position = ride_point(t)
	if t >= 1.0:
		var done := _npc_rider
		_npc_rider = null
		done.reached_pool(ride_point(1.0))

func _dispatch() -> void:
	if _queue.is_empty():
		return
	var front = _queue[0]
	if front is PlayerController:
		if front == _player_in_queue:
			_queue.pop_front()
			_start_ride(front)
	elif front is NPCAgent:
		if front.state == NPCAgent.St.IN_QUEUE \
			and front.global_position.distance_to(slot_position(0)) < 1.3:
			_queue.pop_front()
			_npc_rider = front
			front.begin_ride()

func _update_light() -> void:
	var busy := _rider != null or _npc_rider != null
	var player_next := (not busy) and not _queue.is_empty() and _queue[0] is PlayerController
	if _light_green:
		_light_green.visible = player_next
	if _light_red:
		_light_red.visible = not player_next
	if player_next and not _was_player_next:
		EventBus.toast.emit("Вы следующий — заходите кататься!")
	_was_player_next = player_next

func _finish() -> void:
	var rider := _rider
	var exit_vel := (-_follow.global_transform.basis.z) * (_speed * WeightSystem.speed_factor())
	_rider = null
	_speed = 0.0
	rider.dismount(_follow.global_transform, exit_vel)
	EventBus.slide_completed.emit(Net.local_id(), slide_id)
	await get_tree().create_timer(0.8).timeout
	if is_instance_valid(_mount):
		_mount.monitoring = true
