extends Area3D
class_name WeighStation
## Пункт взвешивания (POI). Игрок постоянно видит только калории; точный вес
## узнаёт, подойдя к весам (тост). Виден на карте/миникарте. Строит свой киоск+зону.

var _cooldown: float = 0.0

func _ready() -> void:
	add_to_group("poi_weigh")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 3, 3)
	cs.shape = box
	add_child(cs)

	var kiosk := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.2, 2.0, 1.2)
	kiosk.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.7, 0.5)
	kiosk.material_override = mat
	kiosk.position = Vector3(0, 1.0, 0)
	add_child(kiosk)

	var label := Label3D.new()
	label.text = "ВЕСЫ"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.pixel_size = 0.012
	label.outline_size = 10
	label.position = Vector3(0, 2.7, 0)
	add_child(label)

	body_entered.connect(_on_enter)

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

func _on_enter(body: Node3D) -> void:
	if body is PlayerController and _cooldown <= 0.0:
		_cooldown = 3.0
		EventBus.toast.emit("Весы: ваш вес %.1f кг   (сожжено %.0f ккал)" % [
			WeightSystem.kg, WeightSystem.calories_burned])
