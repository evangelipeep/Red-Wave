extends Area3D
class_name BardPOI
## Бард (POI). Подходишь → «фото с Бардом» (разово) → закрывает атом квеста «bard».
## Позже Бард будет мелькать по парку и вести Балладу в финале (GDD).

func _ready() -> void:
	add_to_group("poi_bard")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 3, 3)
	cs.shape = box
	add_child(cs)

	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.4
	cap.height = 1.9
	body.mesh = cap
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.3, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.1, 0.5)
	body.material_override = mat
	body.position = Vector3(0, 0.95, 0)
	add_child(body)

	var label := Label3D.new()
	label.text = "БАРД ♪"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 44
	label.pixel_size = 0.012
	label.outline_size = 10
	label.modulate = Color(0.9, 0.6, 1.0)
	label.position = Vector3(0, 2.6, 0)
	add_child(label)

	body_entered.connect(_on_enter)

func _on_enter(b: Node3D) -> void:
	if b is PlayerController and not RunState.bard_photo:
		RunState.bard_photo = true
		EventBus.toast.emit("Фото с Бардом! ♪")
