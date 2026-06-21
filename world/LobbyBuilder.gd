extends Node3D
## Лобби-раздевалка ПЕРЕД входом в парк (по рисунку игрока). Та же сцена, что и парк:
## комната пристроена с юга (z 80..132), проём в южной стене парка — розовые двери.
## Игрок спавнится здесь, свободно ходит (часы стоят), идёт на север через двери в парк —
## это запускает день (RunBootstrap.enter_park).
##
## Этап L1 — оболочка: пол/стены/потолок, розовые двери + триггер входа, футбат,
## турникеты/касса/скамейки, таблички. Функциональные POI (ресепшн/туалет/душ/шкафчики) —
## ставит LobbyBuilder на этапах L2/L3.

const Z_NORTH := 80.0    # общая стена с парком (там проём/двери)
const Z_SOUTH := 132.0
const HALF_X := 36.0
const CEIL_H := 8.0
const DOOR_HALF := 9.0   # половина ширины проёма в стене парка (x −9..9)

func _ready() -> void:
	_build_shell()
	_build_doors()
	_build_entrance()
	_build_facilities()
	_build_labels()

func _build_facilities() -> void:
	# Душевые и туалет — на севере (у выхода в парк, как на рисунке).
	for sx in [-16.0, 16.0]:
		var sh := ShowerPOI.new()
		sh.position = Vector3(sx, 0, 88.0)
		add_child(sh)
	for tx in [-30.0, 30.0]:
		var wc := ToiletCabinPOI.new()
		wc.position = Vector3(tx, 0, 88.0)
		add_child(wc)
	# Весы у входа в зону (как на рисунке).
	for wx in [-32.0, 32.0]:
		_box(Vector3(1.6, 0.4, 1.6), Vector3(wx, 0.2, 94.0), Look.METAL, false)
		_label("ВЕСЫ", Vector3(wx, 1.4, 94.0), Color(0.8, 0.85, 0.9))
	# Шкафчики (зелёные банки) по бокам от ресепшна.
	for lx in [-22.0, 22.0]:
		var lk := LockerPOI.new()
		lk.position = Vector3(lx, 0, 104.0)
		add_child(lk)
	# Ресепшн по центру (доп.желания подключит этап L3 — пока стойка-декор).
	_box(Vector3(6.0, 1.1, 2.5), Vector3(0, 0.55, 106.0), Look.ACCENT)
	_label("РЕСЕПШН", Vector3(0, 2.4, 106.0), Color(1.0, 0.7, 0.4))
	# Кабинки для раздевания (красные) у дальней стены.
	for cx in [-28.0, 28.0]:
		_box(Vector3(3.0, 2.4, 3.0), Vector3(cx, 1.2, 118.0), Look.WAVE, false)
	_label("КАБИНКИ ДЛЯ ПЕРЕОДЕВАНИЯ", Vector3(0, 3.0, 118.0), Color(1.0, 0.55, 0.55))

func _box(size: Vector3, pos: Vector3, col: Color, nav := true, transparent := false) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.size = size
	b.position = pos
	b.use_collision = not transparent
	b.material = Look.mat(col, not transparent, transparent)
	if nav and not transparent:
		b.add_to_group("navsource")
	add_child(b)
	return b

func _build_shell() -> void:
	var cz := (Z_NORTH + Z_SOUTH) * 0.5
	var depth := Z_SOUTH - Z_NORTH
	# Пол.
	_box(Vector3(HALF_X * 2, 1.0, depth), Vector3(0, -0.5, cz), Look.SAND)
	# Потолок.
	_box(Vector3(HALF_X * 2, 0.4, depth), Vector3(0, CEIL_H, cz), Look.STONE, false)
	# Боковые стены.
	_box(Vector3(1.0, CEIL_H, depth), Vector3(-HALF_X, CEIL_H * 0.5, cz), Look.STONE)
	_box(Vector3(1.0, CEIL_H, depth), Vector3(HALF_X, CEIL_H * 0.5, cz), Look.STONE)
	# Южная стена (вход за спиной игрока).
	_box(Vector3(HALF_X * 2, CEIL_H, 1.0), Vector3(0, CEIL_H * 0.5, Z_SOUTH), Look.STONE)

func _build_doors() -> void:
	# Розовые раздвижные двери в проёме южной стены парка (z=80), сдвинуты по краям —
	# центр открыт для прохода. Перед ними — неглубокий «футбат» (вода для прохода).
	var pink := Color(1.0, 0.5, 0.8)
	_box(Vector3(7.0, 4.5, 0.3), Vector3(-5.2, 2.25, Z_NORTH), pink)
	_box(Vector3(7.0, 4.5, 0.3), Vector3(5.2, 2.25, Z_NORTH), pink)
	# Футбат — мелкая вода для прохода (визуал).
	_box(Vector3(12.0, 0.15, 3.0), Vector3(0, 0.1, Z_NORTH + 2.0), Color(0.2, 0.55, 0.95, 0.5), false, true)
	# Триггер входа в парк: пройдя по центру — стартует день.
	var exit_area := Area3D.new()
	exit_area.name = "ParkDoor"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0 * DOOR_HALF, 4.0, 2.0)
	cs.shape = box
	exit_area.add_child(cs)
	exit_area.position = Vector3(0, 2.0, Z_NORTH)
	exit_area.body_entered.connect(_on_park_door)
	add_child(exit_area)

func _on_park_door(body: Node3D) -> void:
	if body is PlayerController:
		get_parent().enter_park()   # RunBootstrap (корень сцены)

func _build_entrance() -> void:
	# Турникеты (север от спавна), касса, скамейки.
	for tx in [-3.0, 0.0, 3.0]:
		_box(Vector3(0.6, 1.1, 0.6), Vector3(tx, 0.55, 124.0), Look.METAL)
	_box(Vector3(4.0, 2.2, 2.0), Vector3(-14.0, 1.1, 126.0), Look.ACCENT)   # касса
	_box(Vector3(5.0, 0.5, 1.0), Vector3(12.0, 0.5, 121.0), Look.WOOD, false)  # скамья
	_box(Vector3(5.0, 0.5, 1.0), Vector3(-20.0, 0.5, 121.0), Look.WOOD, false) # скамья

func _label(text: String, pos: Vector3, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 90
	l.pixel_size = 0.018
	l.modulate = col
	l.outline_size = 12
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	add_child(l)

func _build_labels() -> void:
	_label("РАЗДЕВАЛКА", Vector3(0, 6.5, 106.0), Color(0.95, 0.9, 1.0))
	_label("ВЫХОД В ПАРК →", Vector3(0, 5.0, Z_NORTH + 1.0), Color(1.0, 0.6, 0.85))
	_label("КАССА", Vector3(-14.0, 3.0, 126.0), Color(1.0, 0.8, 0.4))
	_label("ТУРНИКЕТЫ", Vector3(0, 2.2, 124.0), Color(0.8, 0.85, 0.9))
