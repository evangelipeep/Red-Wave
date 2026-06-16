extends Area3D
class_name TheaterPOI
## Театр (POI). Во время шоу (Clock шлёт show_1/2/3) нахождение игрока внутри
## засчитывает посещение — для квеста «Театры×k». Строит сцену+зону+вывеску.

var player_inside: bool = false

func _ready() -> void:
	add_to_group("poi_theater")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(7, 4, 7)
	cs.shape = box
	add_child(cs)

	var stage := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(6, 0.5, 6)
	stage.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.3, 0.6)
	stage.material_override = mat
	stage.position = Vector3(0, 0.25, 0)
	add_child(stage)

	var label := Label3D.new()
	label.text = "ТЕАТР"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.pixel_size = 0.012
	label.outline_size = 10
	label.position = Vector3(0, 3.0, 0)
	add_child(label)

	body_entered.connect(func(b): if b is PlayerController: player_inside = true)
	body_exited.connect(func(b): if b is PlayerController: player_inside = false)
