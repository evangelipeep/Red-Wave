extends Node3D
## Комплекс «Сердце» — многоуровневое здание (greybox по концепту):
## 3 уровня (вход / семейный / приключения), пандусы между ними, стеклянные стены.
## Этажи «отступают» к +Z (юг), а горки стартуют с их СЕВЕРНОГО края и уходят вниз
## в открытое пространство (без пересечения нижних этажей). Поднимаешься по пандусам.
## Горки переиспользуют SlideRail (build_access=false, top_height = высота этажа).

const FLOOR2_Y := 7.0
const FLOOR3_Y := 14.0

func _ready() -> void:
	# Этажи (юг от центра здания), уменьшаются кверху.
	_floor("2 СЕМЕЙНАЯ", Vector3(0, FLOOR2_Y - 0.25, 12), Vector3(30, 0.5, 22), Color(0.5, 0.6, 0.75))
	_floor("3 ПРИКЛЮЧЕНИЯ", Vector3(0, FLOOR3_Y - 0.25, 15), Vector3(22, 0.5, 16), Color(0.7, 0.5, 0.55))
	_label("СЕРДЦЕ", Vector3(0, FLOOR3_Y + 5, 15), Color(1, 0.4, 0.4))
	_label("1 ВХОД", Vector3(0, 2.5, 26), Color(0.8, 0.9, 1.0))

	# Пандусы: земля → 2 этаж → 3 этаж (по южной стороне).
	_ramp(Vector3(0, 0, 28), Vector3(0, FLOOR2_Y, 22), 9.0)
	_ramp(Vector3(0, FLOOR2_Y, 21), Vector3(0, FLOOR3_Y, 17), 7.0)

	# Стеклянные перила-стены по периметру этажей (прозрачные).
	_glass_rail(Vector3(0, FLOOR2_Y, 12), 30, 22)
	_glass_rail(Vector3(0, FLOOR3_Y, 15), 22, 16)

	# Горки: 2 семейные со 2 этажа + 1 экстрим с 3-го (стартуют у северного края, вниз на север).
	_slide("plashch", Vector3(-9, 0, 3), FLOOR2_Y, false)
	_slide("krylo", Vector3(9, 0, 3), FLOOR2_Y, false)
	_slide("klyk", Vector3(0, 0, 8), FLOOR3_Y, true)

# Тун-материал через фабрику Look (см. autoload/Look.gd).
func _mat(c: Color, transparent := false) -> ShaderMaterial:
	return Look.mat(c, not transparent, transparent)

func _floor(name_text: String, pos: Vector3, size: Vector3, col: Color) -> void:
	var f := CSGBox3D.new()
	f.size = size
	f.position = pos
	f.use_collision = true
	f.material = _mat(col)
	f.add_to_group("navsource")
	add_child(f)
	_label(name_text, pos + Vector3(0, 3.5, 0), col)

func _ramp(base: Vector3, top: Vector3, width: float) -> void:
	var ramp := CSGBox3D.new()
	ramp.size = Vector3(width, 0.4, base.distance_to(top) + 0.5)
	ramp.use_collision = true
	ramp.material = _mat(Color(0.6, 0.55, 0.5))
	ramp.transform = Transform3D(Basis.looking_at((top - base).normalized(), Vector3.UP), (base + top) * 0.5)
	ramp.add_to_group("navsource")
	add_child(ramp)

func _glass_rail(center: Vector3, sx: float, sz: float) -> void:
	var glass := _mat(Color(0.6, 0.85, 1.0, 0.18), true)
	var h := 1.4
	var y := center.y + h * 0.5
	_rail_seg(Vector3(center.x, y, center.z + sz * 0.5), Vector3(sx, h, 0.2), glass)
	_rail_seg(Vector3(center.x + sx * 0.5, y, center.z), Vector3(0.2, h, sz), glass)
	_rail_seg(Vector3(center.x - sx * 0.5, y, center.z), Vector3(0.2, h, sz), glass)

func _rail_seg(pos: Vector3, size: Vector3, mat: Material) -> void:
	var s := CSGBox3D.new()
	s.size = size
	s.position = pos
	s.material = mat
	add_child(s)

func _slide(slide_id: String, pos: Vector3, floor_y: float, extreme_race: bool) -> void:
	var s := SlideRail.new()
	s.slide_id = slide_id
	s.top_height = floor_y
	s.build_access = false   # старт на этаже здания, свой пандус не нужен
	s.is_race = false
	s.position = pos
	add_child(s)

func _label(text: String, pos: Vector3, col: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 90
	label.pixel_size = 0.02
	label.modulate = col
	label.outline_size = 12
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = pos
	add_child(label)
