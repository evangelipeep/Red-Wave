extends Node3D
class_name StallPOI
## Лавка фуд-корта. Этап 2 — только визуал (корпус/прилавок/вывеска цвета лавки).
## Этап 3 добавит 3 зоны (очередь/заказ/выдача), меню, оплату, пищалку и FIFO-кухню.

@export var stall_id: String = "fastfood"

func _ready() -> void:
	_build_visuals()

func _build_visuals() -> void:
	var col := FoodMenu.stall_color(stall_id)
	# Корпус лавки.
	var body := CSGBox3D.new()
	body.size = Vector3(4.0, 3.0, 2.6)
	body.position = Vector3(0, 1.5, 0)
	body.use_collision = true
	body.material = _mat(col)
	body.add_to_group("navsource")
	add_child(body)
	# Прилавок (светлее корпуса) спереди (+Z — куда подходит игрок).
	var counter := CSGBox3D.new()
	counter.size = Vector3(4.4, 0.5, 1.0)
	counter.position = Vector3(0, 1.05, 1.7)
	counter.use_collision = true
	counter.material = _mat(col.lightened(0.3))
	counter.add_to_group("navsource")
	add_child(counter)
	# Козырёк.
	var awning := CSGBox3D.new()
	awning.size = Vector3(4.6, 0.25, 1.6)
	awning.position = Vector3(0, 2.9, 1.6)
	awning.material = _mat(col.darkened(0.2))
	add_child(awning)
	# Вывеска.
	var label := Label3D.new()
	label.text = FoodMenu.stall_name(stall_id)
	label.font_size = 80
	label.pixel_size = 0.02
	label.modulate = col.lightened(0.5)
	label.outline_size = 12
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 3.7, 0)
	add_child(label)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m
