extends CharacterBody3D
class_name Cleaner
## Уборщик фуд-корта: подходит к бесхозной выброшенной еде (старше CLEAN_AFTER) и убирает.
## Когда убирать нечего — стоит у мусорки. Один на фуд-корт (спавнит FoodCourtManager).

const CLEAN_AFTER_MIN := 20.0
const DAY_MINUTES := 720.0

@export var speed: float = 3.0

var _target: Node3D = null
var _home: Vector3 = Vector3.ZERO
var _stuck_t: float = 0.0
var _grav: float = ProjectSettings.get_setting("physics/3d/default_gravity", 18.0)
var _nav: NavigationAgent3D
var _knock: Vector3 = Vector3.ZERO

func apply_knock(v: Vector3) -> void:
	_knock = v

func _ready() -> void:
	add_to_group("cleaner")
	add_to_group("knockable")
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.7
	var col := CollisionShape3D.new()
	col.shape = cap
	col.position = Vector3(0, 0.85, 0)
	add_child(col)
	var mesh := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.34
	cm.height = 1.7
	mesh.mesh = cm
	mesh.material_override = Look.mat(Color(0.4, 0.55, 0.7))   # уборщик — серо-синий
	mesh.position = Vector3(0, 0.85, 0)
	add_child(mesh)
	var label := Label3D.new()
	label.text = "Уборщик"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 30
	label.pixel_size = 0.011
	label.outline_size = 6
	label.position = Vector3(0, 2.0, 0)
	add_child(label)
	_nav = NavigationAgent3D.new()
	_nav.path_desired_distance = 0.6
	_nav.target_desired_distance = 0.6
	_nav.avoidance_enabled = false
	add_child(_nav)

func _physics_process(delta: float) -> void:
	if _knock.length() > 0.3:
		velocity = _knock
		velocity.y = (velocity.y - _grav * delta) if not is_on_floor() else 0.0
		move_and_slide()
		_knock = _knock.move_toward(Vector3.ZERO, delta * 18.0)
		return
	if _home == Vector3.ZERO:
		_home = _find_home()
	if _target == null or not is_instance_valid(_target):
		_target = _find_old_food()
	if _target != null:
		_step(_target.global_position, delta)
		_antistuck(_target.global_position, delta)
		if _near(_target.global_position):
			var mgr = get_tree().get_first_node_in_group("food_court_mgr")
			if mgr != null:
				mgr.remove_dropped(_target.net_id)   # в коопе уборка через хоста
			else:
				_target.queue_free()
			_target = null
	elif not _near(_home):
		_step(_home, delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = (velocity.y - _grav * delta) if not is_on_floor() else 0.0
		move_and_slide()

func _find_old_food() -> Node3D:
	var t := Clock.day_fraction
	for d in get_tree().get_nodes_in_group("dropped_food"):
		if t - float(d.spawned_at) >= CLEAN_AFTER_MIN / DAY_MINUTES:
			return d as Node3D
	return null

func _find_home() -> Vector3:
	var trash := get_tree().get_first_node_in_group("food_trash")
	if trash != null:
		return (trash as Node3D).global_position
	return global_position

func _step(target: Vector3, delta: float) -> void:
	_nav.target_position = target
	var next := _nav.get_next_path_position()
	var flat := Vector3(next.x - global_position.x, 0.0, next.z - global_position.z)
	if flat.length() > 0.3:
		var dir := flat.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)
	velocity.y = (velocity.y - _grav * delta) if not is_on_floor() else 0.0
	move_and_slide()

func _near(target: Vector3) -> bool:
	return Vector2(target.x - global_position.x, target.z - global_position.z).length() < 1.0

func _antistuck(target: Vector3, delta: float) -> void:
	var rv := get_real_velocity()
	if Vector2(rv.x, rv.z).length() < 0.3 and not _near(target):
		_stuck_t += delta
		if _stuck_t > 4.0:
			global_position = Vector3(target.x, global_position.y, target.z)
			_stuck_t = 0.0
	else:
		_stuck_t = 0.0
