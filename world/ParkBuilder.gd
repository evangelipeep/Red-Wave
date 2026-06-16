extends Node3D
## Большая основная территория крытого аквапарка «Красная Волна» (greybox).
## Купол + высокие стены (3 этажа), панорама со стороны «Зеро» (закат там же).
## 3 зоны: Северный Клык (слева, комплекс «Сердце»), Дельта (справа), Серый Пояс Зеро
## (сверху). Бассейн «Волны» в центре, река-капилляр уходит от него в стороны.
## Горки (комплекс Сердце + по одной в Дельте/Зеро) расставлены в сцене ParkGreybox.
## Фундаменты будущих объектов (Рулетка, Рой, Комар, Магазин) намечены площадками.

const HALF_X := 100.0
const HALF_Z := 80.0
const WALL_H := 16.0          # ~3 этажа
const WAVE_POOL := Vector3(0, 0, 22)
const WAVE_RADIUS := 14.0

const ZONES := [
	{"id": "klyk",  "name": "Северный Клык (Сердце)", "pos": Vector3(-58, 0, 0),  "col": Color(0.5, 0.7, 1.0)},
	{"id": "delta", "name": "Дельта",                 "pos": Vector3(58, 0, -6),  "col": Color(1.0, 0.7, 0.4)},
	{"id": "zero",  "name": "Серый Пояс Зеро",        "pos": Vector3(0, 0, -55),  "col": Color(0.62, 0.62, 0.68)},
]

const FOUNDATIONS := [
	{"name": "Рулетка",  "pos": Vector3(-26, 0, -58), "r": 9.0},
	{"name": "Рой",      "pos": Vector3(42, 0, -52),  "r": 9.0},
	{"name": "Комар",    "pos": Vector3(80, 0, -22),  "r": 9.0},
	{"name": "Магазин",  "pos": Vector3(-72, 0, 52),  "r": 7.0},
]

func _ready() -> void:
	_build_ground()
	_build_walls_and_dome()
	_build_pad(WAVE_POOL, WAVE_RADIUS + 2.0, Color(0.5, 0.2, 0.2))
	_build_wave_pool()
	_build_capillary()
	_build_label("ВОЛНЫ", WAVE_POOL + Vector3(0, 4, 0), Color(0.9, 0.5, 0.5))
	_build_label("СПАВН →", Vector3(0, 3, 60), Color(1, 1, 1))
	for z in ZONES:
		_build_pad(z["pos"], 18.0, Color(z["col"].r, z["col"].g, z["col"].b, 0.5))
		_build_zone_area(z["id"], z["pos"])
		_build_label(z["name"], z["pos"] + Vector3(0, 7, 0), z["col"])
	for f in FOUNDATIONS:
		_build_foundation(f["name"], f["pos"], f["r"])
	_build_weigh(Vector3(14, 0, 40))
	_build_weigh(Vector3(-14, 0, 40))
	_build_theater(Vector3(0, 0, -8))

func _mat(c: Color, transparent := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _build_ground() -> void:
	var ground := CSGCombiner3D.new()
	ground.name = "Ground"
	ground.use_collision = true
	ground.add_to_group("ground")   # горки сами выкопают ямы под бассейны
	add_child(ground)
	var floor_box := CSGBox3D.new()
	floor_box.size = Vector3(HALF_X * 2, 14, HALF_Z * 2)
	floor_box.position = Vector3(0, -7, 0)
	floor_box.material = _mat(Color(0.45, 0.48, 0.5))
	ground.add_child(floor_box)

func _build_walls_and_dome() -> void:
	var solid := _mat(Color(0.35, 0.33, 0.4))
	var glass := _mat(Color(0.6, 0.8, 1.0, 0.25), true)
	# Стены по периметру (3 этажа). Северная (−Z, сторона Зеро) — панорамное стекло.
	_wall(Vector3(0, WALL_H * 0.5, HALF_Z), Vector3(HALF_X * 2, WALL_H, 2), solid)    # юг
	_wall(Vector3(HALF_X, WALL_H * 0.5, 0), Vector3(2, WALL_H, HALF_Z * 2), solid)    # восток
	_wall(Vector3(-HALF_X, WALL_H * 0.5, 0), Vector3(2, WALL_H, HALF_Z * 2), solid)   # запад
	_wall(Vector3(0, WALL_H * 0.5, -HALF_Z), Vector3(HALF_X * 2, WALL_H, 1.5), glass) # север (панорама/закат)
	# Стеклянный купол.
	var dome := MeshInstance3D.new()
	dome.name = "Dome"
	var sphere := SphereMesh.new()
	sphere.radius = 150.0
	sphere.height = 300.0
	sphere.radial_segments = 32
	sphere.rings = 16
	dome.mesh = sphere
	dome.position = Vector3(0, WALL_H - 2.0, 0)
	dome.material_override = _mat(Color(0.55, 0.75, 1.0, 0.12), true)
	add_child(dome)

func _wall(pos: Vector3, size: Vector3, mat: StandardMaterial3D) -> void:
	var w := CSGBox3D.new()
	w.size = size
	w.position = pos
	w.use_collision = true
	w.material = mat
	add_child(w)

func _build_pad(pos: Vector3, r: float, col: Color) -> void:
	var pad := CSGCylinder3D.new()
	pad.radius = r
	pad.height = 0.15
	pad.position = pos + Vector3(0, 0.08, 0)
	pad.material = _mat(col, col.a < 1.0)
	add_child(pad)

func _build_zone_area(zone_id: String, pos: Vector3) -> void:
	var area := ZoneTracker.new()
	area.zone_id = zone_id
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 16.0
	shape.height = 8.0
	cs.shape = shape
	area.add_child(cs)
	area.position = pos + Vector3(0, 4, 0)
	add_child(area)

func _build_label(text: String, pos: Vector3, col: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 110
	label.pixel_size = 0.02
	label.modulate = col
	label.outline_size = 14
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = pos
	add_child(label)

func _build_foundation(name_text: String, pos: Vector3, r: float) -> void:
	var pad := CSGCylinder3D.new()
	pad.radius = r
	pad.height = 0.3
	pad.position = pos + Vector3(0, 0.15, 0)
	pad.material = _mat(Color(0.3, 0.3, 0.33))
	add_child(pad)
	_build_label("⌗ " + name_text + "\n(фундамент)", pos + Vector3(0, 3, 0), Color(0.7, 0.7, 0.75))

func _build_wave_pool() -> void:
	var water := MeshInstance3D.new()
	water.name = "WaveWater"
	var cyl := CylinderMesh.new()
	cyl.top_radius = WAVE_RADIUS
	cyl.bottom_radius = WAVE_RADIUS
	cyl.height = 0.4
	water.mesh = cyl
	water.position = WAVE_POOL + Vector3(0, 0.1, 0)
	water.material_override = _mat(Color(0.8, 0.05, 0.05, 0.7), true)
	add_child(water)
	var area := Area3D.new()
	area.name = "WavePoolArea"
	area.add_to_group("water")
	area.set_meta("surface_y", 0.3)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WAVE_RADIUS * 2, 2.0, WAVE_RADIUS * 2)
	cs.shape = box
	area.add_child(cs)
	area.position = WAVE_POOL + Vector3(0, 0.5, 0)
	add_child(area)

func _build_capillary() -> void:
	# Две «ленивые» ветки-капилляры от Волн в стороны (Сердце и Дельта).
	var left := [WAVE_POOL, Vector3(-22, 0, 14), Vector3(-40, 0, 6), Vector3(-55, 0, -10)]
	var right := [WAVE_POOL, Vector3(24, 0, 12), Vector3(48, 0, 2), Vector3(60, 0, -16)]
	_capillary_arm(left)
	_capillary_arm(right)

func _capillary_arm(points: Array) -> void:
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var mid := (a + b) * 0.5
		var dir := (b - a)
		dir.y = 0
		var seg_len := dir.length()
		dir = dir.normalized()
		var basis := Basis.looking_at(dir, Vector3.UP)
		# Вода (визуал).
		var vis := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(5, 0.3, seg_len + 1.0)
		vis.mesh = bm
		vis.material_override = _mat(Color(0.8, 0.05, 0.05, 0.7), true)
		vis.transform = Transform3D(basis, mid + Vector3(0, 0.15, 0))
		add_child(vis)
		# Объём воды + течение вдоль русла.
		var area := Area3D.new()
		area.add_to_group("water")
		area.add_to_group("river")
		area.set_meta("surface_y", 0.3)
		area.set_meta("flow_dir", dir)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(5, 2.0, seg_len + 1.0)
		cs.shape = box
		area.add_child(cs)
		area.transform = Transform3D(basis, mid + Vector3(0, 0.5, 0))
		add_child(area)

func _build_weigh(pos: Vector3) -> void:
	var w := WeighStation.new()
	w.position = pos
	add_child(w)

func _build_theater(pos: Vector3) -> void:
	var t := TheaterPOI.new()
	t.position = pos
	add_child(t)
