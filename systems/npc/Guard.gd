extends CharacterBody3D
class_name Guard
## Охранник: появляется после нарушения очереди и ходит за игроком на дистанции
## нескольких метров (GUARD_FOLLOW_DIST). Лёгкий — простое преследование, коллизия.

@export var speed: float = 4.0

var _grav: float = ProjectSettings.get_setting("physics/3d/default_gravity", 18.0)

func _ready() -> void:
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.9
	var col := CollisionShape3D.new()
	col.shape = cap
	col.position = Vector3(0, 0.95, 0)
	add_child(col)

	var mesh := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.4
	cm.height = 1.9
	mesh.mesh = cm
	mesh.material_override = Look.mat(Color(0.15, 0.18, 0.3))   # тёмная «форма»
	mesh.position = Vector3(0, 0.95, 0)
	add_child(mesh)

	var label := Label3D.new()
	label.text = "ОХРАНА"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.pixel_size = 0.011
	label.outline_size = 8
	label.modulate = Color(1, 0.6, 0.3)
	label.position = Vector3(0, 2.4, 0)
	add_child(label)

func _physics_process(delta: float) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		velocity = Vector3.ZERO
		move_and_slide()
		return
	var p := players[0] as Node3D
	var flat := Vector3(p.global_position.x - global_position.x, 0.0, p.global_position.z - global_position.z)
	if flat.length() > GameConstants.GUARD_FOLLOW_DIST:
		var dir := flat.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)
	velocity.y = (velocity.y - _grav * delta) if not is_on_floor() else 0.0
	move_and_slide()
