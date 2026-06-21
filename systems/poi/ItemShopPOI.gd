extends Area3D
class_name ItemShopPOI
## Магазин предметов: подойди, нажми E — откроется меню покупки
## (таблетки от тошноты, пистолет-отталкиватель).

var _inside: bool = false

func _ready() -> void:
	add_to_group("poi_itemshop")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.5, 3, 3.5)
	cs.shape = box
	cs.position = Vector3(0, 1.5, 0)
	add_child(cs)
	var kiosk := CSGBox3D.new()
	kiosk.size = Vector3(2.0, 2.4, 1.6)
	kiosk.position = Vector3(0, 1.2, 0)
	kiosk.use_collision = true
	kiosk.material = _mat(Color(0.2, 0.5, 0.55))
	kiosk.add_to_group("navsource")
	add_child(kiosk)
	var label := Label3D.new()
	label.text = "МАГАЗИН\n(E)"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 44
	label.pixel_size = 0.012
	label.outline_size = 10
	label.modulate = Color(0.6, 0.9, 0.95)
	label.position = Vector3(0, 3.0, 0)
	add_child(label)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	EventBus.interact_pressed.connect(_on_interact)

func _on_enter(b: Node3D) -> void:
	if b is PlayerController:
		_inside = true
		EventBus.toast.emit("Магазин: нажми E — таблетки и пистолет.")

func _on_exit(b: Node3D) -> void:
	if b is PlayerController:
		_inside = false

func _on_interact() -> void:
	if not _inside:
		return
	var m = get_tree().get_first_node_in_group("item_shop_menu")
	if m != null:
		m.open()

# Тун-материал через фабрику Look (см. autoload/Look.gd).
func _mat(c: Color) -> ShaderMaterial:
	return Look.mat(c)
