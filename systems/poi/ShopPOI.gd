extends Area3D
class_name ShopPOI
## Лавка (POI). Подходишь → покупаешь сувенир за монеты (по одному с лавки).
## Сувениры из 3 разных лавок закрывают квест «Сувенир из каждой лавки».

@export var shop_id: String = "shop"
const COST := 2

var _cd: float = 0.0

func _ready() -> void:
	add_to_group("poi_shop")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 3, 3)
	cs.shape = box
	add_child(cs)

	var kiosk := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.6, 2.2, 1.2)
	kiosk.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.7, 0.3)
	kiosk.material_override = mat
	kiosk.position = Vector3(0, 1.1, 0)
	add_child(kiosk)

	var label := Label3D.new()
	label.text = "ЛАВКА"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 44
	label.pixel_size = 0.012
	label.outline_size = 10
	label.position = Vector3(0, 2.9, 0)
	add_child(label)

	body_entered.connect(_on_enter)

func _process(delta: float) -> void:
	if _cd > 0.0:
		_cd -= delta

func _on_enter(body: Node3D) -> void:
	if not (body is PlayerController) or _cd > 0.0:
		return
	_cd = 3.0
	if RunState.souvenirs.has(shop_id):
		EventBus.toast.emit("Сувенир из этой лавки уже куплен")
	elif RunState.coins < COST:
		EventBus.toast.emit("Не хватает монет на сувенир (нужно %d)" % COST)
	else:
		RunState.coins -= COST
		RunState.souvenirs[shop_id] = true
		EventBus.toast.emit("Сувенир куплен! (%d/3)" % RunState.souvenirs.size())
