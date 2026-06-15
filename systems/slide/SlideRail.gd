extends Node3D
class_name SlideRail
## Спуск с горки по сплайну от первого лица — ГЛАВНЫЙ риск фазы 1.
## Игрок входит в зону старта сверху → SlideRail ведёт его по Path3D вниз.
## Скорость: разгон на уклоне (gravity·slope) − сопротивление, всё умножается
## на WeightSystem.speed_factor() (тяжелее = быстрее, GDD §5). Достиг низа
## («бассейн», баг #21) → EventBus.slide_completed + высадка.
##
## Для прототипа умеет сам собрать тестовый сплайн и лестницу доступа
## (build_demo_curve / build_access). Реальные горки получат свой Path3D в редакторе.

@export var slide_id: String = "klyk"
@export var base_speed: float = 6.0        # стартовый толчок, м/с
@export var max_speed: float = 22.0
@export var drag: float = 0.25             # сопротивление, 1/с
@export var build_demo_curve: bool = true  # собрать тестовый сплайн, если Path пуст
@export var build_access: bool = true      # собрать лестницу к старту (для теста)

var _path: Path3D
var _follow: PathFollow3D
var _mount: Area3D
var _rider: PlayerController = null
var _speed: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

func _ready() -> void:
	_setup_path()
	_setup_follow()
	_setup_mount()
	_build_visuals()
	_build_pool()
	if build_access and build_demo_curve:
		_build_access_stairs(_path.curve.get_point_position(0))

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
	# Пологий S-спуск ~22 м: сверху (y=4.5) вниз в «бассейн» (y=0.3).
	var pts := [
		Vector3(0, 4.5, 0),
		Vector3(0, 3.6, -5),
		Vector3(2.5, 2.6, -9),
		Vector3(2.5, 1.6, -13),
		Vector3(-1, 0.8, -17),
		Vector3(0, 0.3, -21),
	]
	for p in pts:
		c.add_point(p)
	# Curve3D с нулевыми хэндлами линейна — задаём касательные по соседям (сглаживание).
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
	_mount = get_node_or_null("Mount") as Area3D
	if _mount == null:
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

func _build_access_stairs(top: Vector3) -> void:
	var steps := 10
	for i in range(steps):
		var f := float(i) / float(steps - 1)
		var step := CSGBox3D.new()
		step.size = Vector3(3, 0.4, 1.2)
		step.use_collision = true
		step.position = Vector3(top.x, top.y * f - 0.2, top.z + float(steps - i) * 1.2)
		add_child(step)
	# площадка наверху, чтобы было где встать перед стартом
	var plat := CSGBox3D.new()
	plat.name = "TopPlatform"
	plat.size = Vector3(3, 0.4, 2.5)
	plat.use_collision = true
	plat.position = Vector3(top.x, top.y - 0.2, top.z + 0.8)
	add_child(plat)

# --- Видимая геометрия горки и воды ---
func _make_material(col: Color, transparent: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _build_visuals() -> void:
	# Жёлоб вдоль сплайна (U-профиль, открыт сверху — видно ездока).
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
	add_child(tube)
	tube.path_node = tube.get_path_to(_path)
	tube.material = _make_material(Color(0.4, 0.7, 1.0, 0.55), true)

func _build_pool() -> void:
	var end := _path.curve.get_point_position(_path.curve.point_count - 1)
	var center := end + Vector3(0, -0.1, -2)
	# Красная вода (полупрозрачный диск).
	var water := MeshInstance3D.new()
	water.name = "Water"
	var disc := CylinderMesh.new()
	disc.top_radius = 5.0
	disc.bottom_radius = 5.0
	disc.height = 0.3
	water.mesh = disc
	water.position = center
	water.material_override = _make_material(Color(0.85, 0.05, 0.05, 0.7), true)
	add_child(water)
	# Зона воды для плавания (группа "water" — активирует swim в PlayerController).
	var area := Area3D.new()
	area.name = "Pool"
	area.add_to_group("water")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 2.0, 10)
	cs.shape = box
	area.add_child(cs)
	area.position = center + Vector3(0, 0.8, 0)
	add_child(area)

func _on_mount_body_entered(body: Node3D) -> void:
	if _rider != null:
		return
	if body is PlayerController:
		_start_ride(body)

func _start_ride(player: PlayerController) -> void:
	_rider = player
	_speed = base_speed
	_follow.progress = 0.0
	_mount.monitoring = false
	player.mount_rail(self)

func _physics_process(delta: float) -> void:
	if _rider == null:
		return
	var fwd := -_follow.global_transform.basis.z   # направление движения
	var slope := -fwd.y                            # >0 на спуске
	_speed += (_gravity * slope - drag * _speed) * delta
	_speed = clampf(_speed, 1.0, max_speed)
	var eff := _speed * WeightSystem.speed_factor()
	_follow.progress += eff * delta

	_rider.ride_to(_follow.global_transform, clampf(eff / max_speed, 0.0, 1.0), delta)

	if _follow.progress_ratio >= 1.0:
		_finish()

func _finish() -> void:
	var rider := _rider
	_rider = null
	_speed = 0.0
	rider.dismount(_follow.global_transform)
	EventBus.slide_completed.emit(Net.local_id(), slide_id)
	print("[SlideRail] %s — бассейн достигнут" % slide_id)
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(_mount):
		_mount.monitoring = true
