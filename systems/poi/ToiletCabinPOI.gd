extends Area3D
class_name ToiletCabinPOI
## Туалетная кабинка в раздевалке: зашёл — сходил в туалет (−вес, кулдаун как у кнопки T,
## мексиканское «остро» снимает кулдаун). Заменяет хождение по кнопке: теперь физически
## заходишь в кабинку.

func _ready() -> void:
	add_to_group("poi_toilet")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 2.5, 1.8)
	cs.shape = box
	cs.position = Vector3(0, 1.25, 0)
	add_child(cs)
	# Кабинка: стенки + дверь.
	var hut := CSGBox3D.new()
	hut.size = Vector3(2.0, 2.6, 2.0)
	hut.position = Vector3(0, 1.3, 0)
	hut.use_collision = false   # внутрь надо заходить
	hut.material = Look.mat(Color(0.85, 0.85, 0.9))
	add_child(hut)
	var label := Label3D.new()
	label.text = "ТУАЛЕТ"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.pixel_size = 0.012
	label.outline_size = 8
	label.position = Vector3(0, 3.0, 0)
	add_child(label)
	body_entered.connect(_on_enter)

func _on_enter(body: Node3D) -> void:
	if not (body is PlayerController):
		return
	if WeightSystem.toilet():
		EventBus.toast.emit("Сходил в туалет — стало легче (%.0f кг)." % WeightSystem.kg)
	else:
		EventBus.toast.emit("Туалет: рано (ещё %.1f ч)." % WeightSystem.toilet_ready_in_hours())
