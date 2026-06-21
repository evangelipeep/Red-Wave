extends CharacterBody3D
class_name Visitor
## Фоновый посетитель: просто гуляет по парку между случайными точками (коллизия,
## без навмеша + анти-стак). Не взаимодействует с горками — оживляет территорию.

@export var speed: float = 2.6

var _target: Vector3 = Vector3.ZERO
var _retarget_t: float = 0.0
var _stuck_t: float = 0.0
var _grav: float = ProjectSettings.get_setting("physics/3d/default_gravity", 18.0)
var _nav: NavigationAgent3D
var _rig: CharacterRig
var _knock: Vector3 = Vector3.ZERO

func apply_knock(v: Vector3) -> void:
	_knock = v

func _ready() -> void:
	add_to_group("knockable")
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	var col := CollisionShape3D.new()
	col.shape = cap
	col.position = Vector3(0, 0.9, 0)
	add_child(col)
	# Тело-силуэт (тот же CharacterRig, что у игрока) — потом заменишь на модель.
	_rig = CharacterRig.make(randf_range(1.6, 1.85),
		Color.from_hsv(0.07, 0.35, randf_range(0.6, 0.85)),   # кожа
		Color.from_hsv(randf(), 0.5, 0.8),                    # одежда
		false, randf_range(0.85, 1.2))
	add_child(_rig)
	_nav = NavigationAgent3D.new()
	_nav.path_desired_distance = 0.6
	_nav.target_desired_distance = 0.6
	_nav.avoidance_enabled = false
	add_child(_nav)
	global_position = _rand_point()
	_pick()

func _rand_point() -> Vector3:
	return Vector3(randf_range(-85, 85), 0.4, randf_range(-65, 65))

func _pick() -> void:
	_target = _rand_point()
	_retarget_t = randf_range(4.0, 9.0)
	_stuck_t = 0.0

func _physics_process(delta: float) -> void:
	if _knock.length() > 0.3:
		velocity = _knock
		velocity.y = (velocity.y - _grav * delta) if not is_on_floor() else 0.0
		move_and_slide()
		_knock = _knock.move_toward(Vector3.ZERO, delta * 18.0)
		return
	_nav.target_position = _target
	var next := _nav.get_next_path_position()
	var flat := Vector3(next.x - global_position.x, 0.0, next.z - global_position.z)
	var to_target := Vector3(_target.x - global_position.x, 0.0, _target.z - global_position.z)
	if flat.length() > 0.4:
		var dir := flat.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)
	velocity.y = (velocity.y - _grav * delta) if not is_on_floor() else 0.0
	move_and_slide()
	_drive_rig(delta)

	_retarget_t -= delta
	var rv := get_real_velocity()
	if Vector2(rv.x, rv.z).length() < 0.3 and to_target.length() > 1.5:
		_stuck_t += delta
	else:
		_stuck_t = 0.0
	if _retarget_t <= 0.0 or to_target.length() <= 1.0:
		_pick()
	elif _stuck_t > 4.0:
		global_position = Vector3(_target.x, global_position.y, _target.z)  # аварийно
		_pick()

# Ведём анимацию тела и поворачиваем силуэт по направлению движения.
func _drive_rig(delta: float) -> void:
	if not _rig:
		return
	var pv := Vector3(velocity.x, 0.0, velocity.z)
	if pv.length() > 0.3:
		var yaw := atan2(-pv.x, -pv.z)
		_rig.rotation.y = lerp_angle(_rig.rotation.y, yaw, clampf(delta * 10.0, 0.0, 1.0))
	_rig.animate_ground(pv.length(), speed, is_on_floor(), delta)
