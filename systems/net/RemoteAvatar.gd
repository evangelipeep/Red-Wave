extends Node3D
class_name RemoteAvatar
## Визуальный аватар другого игрока в кооперативе: капсула, плавно догоняет
## присланную позицию/поворот. Не управляется локально.

var _target_pos: Vector3 = Vector3.ZERO
var _target_yaw: float = 0.0
var _mat: StandardMaterial3D
var _label: Label3D

func _ready() -> void:
	var mesh := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.35
	cm.height = 1.7
	mesh.mesh = cm
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(1.0, 0.85, 0.2)   # пока имя не пришло — золотистый
	_mat.emission_enabled = true
	_mat.emission = _mat.albedo_color * 0.4
	mesh.material_override = _mat
	mesh.position = Vector3(0, 0.9, 0)
	add_child(mesh)
	_label = Label3D.new()
	_label.text = "ИГРОК"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 36
	_label.pixel_size = 0.011
	_label.outline_size = 8
	_label.position = Vector3(0, 2.3, 0)
	add_child(_label)

func set_target(pos: Vector3, yaw: float) -> void:
	_target_pos = pos
	_target_yaw = yaw

## Имя и цвет другого игрока (приходят по сети один раз при подключении).
## NB: не «set_identity» — это встроенный метод Node3D (сброс трансформа).
func set_player_identity(pname: String, color: Color) -> void:
	if _label != null:
		_label.text = pname
		_label.modulate = color
	if _mat != null:
		_mat.albedo_color = color
		_mat.emission = color * 0.4

func _process(delta: float) -> void:
	var k := clampf(delta * 12.0, 0.0, 1.0)
	global_position = global_position.lerp(_target_pos, k)
	rotation.y = lerp_angle(rotation.y, _target_yaw, k)
