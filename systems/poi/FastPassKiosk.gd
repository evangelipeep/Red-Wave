extends Area3D
class_name FastPassKiosk
## Киоск Fast Pass: покупаешь пропуск за монеты. С пропуском можно зайти на горку
## без очереди ЛЕГАЛЬНО (без штрафа) — закрывает квест «без очереди».

const COST := 3
var _cd: float = 0.0

func _ready() -> void:
	add_to_group("poi_fastpass")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 3, 3)
	cs.shape = box
	add_child(cs)

	var kiosk := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.4, 2.2, 1.2)
	kiosk.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.8, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.4, 0.45)
	kiosk.material_override = mat
	kiosk.position = Vector3(0, 1.1, 0)
	add_child(kiosk)

	var label := Label3D.new()
	label.text = "FAST PASS"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.pixel_size = 0.012
	label.outline_size = 10
	label.modulate = Color(0.4, 0.95, 1.0)
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
	if RunState.coins < COST:
		EventBus.toast.emit("Не хватает монет на Fast Pass (нужно %d)" % COST)
	else:
		RunState.coins -= COST
		RunState.fast_passes += 1
		EventBus.toast.emit("Куплен Fast Pass (всего %d) — заходи без очереди" % RunState.fast_passes)
