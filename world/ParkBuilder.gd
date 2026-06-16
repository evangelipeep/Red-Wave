extends Node3D
## Greybox-парк (фаза 1): строит примитивами центральную площадь, 3 зоны с
## названиями и детекторами, мосты и ленивую реку-кольцо (плавание + течение).
## Горка ставится отдельно (сцена), сюда — копаем под её бассейн яму.
## NavMesh отложен до NPC (фаза 2): без агентов он невидим.

const RIVER_RADIUS := 21.0
const RIVER_SURFACE_Y := -0.3

const ZONES := [
	{"id": "klyk",  "name": "Северный Клык",      "pos": Vector3(0, 0, -34),  "col": Color(0.5, 0.7, 1.0)},
	{"id": "delta", "name": "Дельта",             "pos": Vector3(29, 0, 17),  "col": Color(1.0, 0.7, 0.4)},
	{"id": "zero",  "name": "Серый Пояс Зеро",    "pos": Vector3(-29, 0, 17), "col": Color(0.62, 0.62, 0.68)},
]

func _ready() -> void:
	_build_ground()
	_build_pad(Vector3.ZERO, 12.0, Color(0.78, 0.78, 0.82))
	_build_label("ЦЕНТР", Vector3(0, 5, 0), Color(1, 1, 1))
	for z in ZONES:
		_build_pad(z["pos"], 9.0, z["col"])
		_build_zone_area(z["id"], z["pos"])
		_build_label(z["name"], z["pos"] + Vector3(0, 5, 0), z["col"])
	# Река-кольцо временно убрана (мешала размещению горки) — вернём при доводке.
	_build_weigh(Vector3(13, 0, 6))
	_build_weigh(Vector3(-13, 0, 6))
	_build_theater(Vector3(-15, 0, -6))

func _build_weigh(pos: Vector3) -> void:
	var w := WeighStation.new()
	w.position = pos
	add_child(w)

func _build_theater(pos: Vector3) -> void:
	var t := TheaterPOI.new()
	t.position = pos
	add_child(t)

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
	floor_box.size = Vector3(140, 14, 140)
	floor_box.position = Vector3(0, -7, 0)
	floor_box.material = _mat(Color(0.45, 0.5, 0.42))
	ground.add_child(floor_box)

	# Траншея под реку-кольцо.
	var trench := CSGTorus3D.new()
	trench.inner_radius = RIVER_RADIUS - 3.5
	trench.outer_radius = RIVER_RADIUS + 3.5
	trench.sides = 12
	trench.ring_sides = 24
	trench.operation = CSGShape3D.OPERATION_SUBTRACTION
	ground.add_child(trench)

func _build_pad(pos: Vector3, r: float, col: Color) -> void:
	var pad := CSGCylinder3D.new()
	pad.radius = r
	pad.height = 0.15
	pad.position = pos + Vector3(0, 0.08, 0)
	pad.material = _mat(col)
	add_child(pad)

func _build_zone_area(zone_id: String, pos: Vector3) -> void:
	var area := ZoneTracker.new()
	area.zone_id = zone_id
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 10.0
	shape.height = 6.0
	cs.shape = shape
	area.add_child(cs)
	area.position = pos + Vector3(0, 3, 0)
	add_child(area)

func _build_label(text: String, pos: Vector3, col: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 96
	label.pixel_size = 0.02
	label.modulate = col
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = pos
	add_child(label)

func _build_bridge(zone_pos: Vector3) -> void:
	var dir := Vector3(zone_pos.x, 0, zone_pos.z).normalized()
	var tangent := Vector3.UP.cross(dir).normalized()
	var b := CSGBox3D.new()
	b.size = Vector3(5, 0.6, 16)   # x — ширина (по касательной), z — длина (по радиусу)
	b.use_collision = true
	b.material = _mat(Color(0.7, 0.6, 0.5))
	b.transform = Transform3D(Basis(tangent, Vector3.UP, dir), dir * 18.0 + Vector3(0, 0.1, 0))
	add_child(b)

func _build_river() -> void:
	var segments := 24
	for i in range(segments):
		var a := TAU * float(i) / float(segments)
		var radial := Vector3(sin(a), 0, cos(a))
		var tangent := Vector3.UP.cross(radial).normalized()
		var basis := Basis(tangent, Vector3.UP, radial)
		var pos := radial * RIVER_RADIUS

		# Вода (визуал, красная у поверхности).
		var vis := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(5.8, 0.3, 6.0)   # x — вдоль кольца, z — поперёк
		vis.mesh = bm
		vis.material_override = _mat(Color(0.8, 0.05, 0.05, 0.7), true)
		vis.transform = Transform3D(basis, pos + Vector3(0, RIVER_SURFACE_Y, 0))
		add_child(vis)

		# Объём воды (плавание + течение по кольцу).
		var area := Area3D.new()
		area.add_to_group("water")
		area.add_to_group("river")
		area.set_meta("surface_y", RIVER_SURFACE_Y)
		area.set_meta("river_center", Vector3.ZERO)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(5.8, 3.0, 6.0)
		cs.shape = box
		area.add_child(cs)
		area.transform = Transform3D(basis, pos + Vector3(0, -1.5, 0))
		add_child(area)
