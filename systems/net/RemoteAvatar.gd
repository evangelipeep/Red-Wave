extends Node3D
class_name RemoteAvatar
## Визуальный аватар другого игрока в кооперативе: капсула, плавно догоняет
## присланную позицию/поворот. Не управляется локально.

var _target_pos: Vector3 = Vector3.ZERO
var _target_yaw: float = 0.0

func _ready() -> void:
	var mesh := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.35
	cm.height = 1.7
	mesh.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2)   # другие игроки — золотистые
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.3, 0.0)
	mesh.material_override = mat
	mesh.position = Vector3(0, 0.9, 0)
	add_child(mesh)
	var label := Label3D.new()
	label.text = "ИГРОК"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 36
	label.pixel_size = 0.011
	label.outline_size = 8
	label.position = Vector3(0, 2.3, 0)
	add_child(label)

func set_target(pos: Vector3, yaw: float) -> void:
	_target_pos = pos
	_target_yaw = yaw

func _process(delta: float) -> void:
	var k := clampf(delta * 12.0, 0.0, 1.0)
	global_position = global_position.lerp(_target_pos, k)
	rotation.y = lerp_angle(rotation.y, _target_yaw, k)
