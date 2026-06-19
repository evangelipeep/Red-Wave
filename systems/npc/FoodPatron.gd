extends CharacterBody3D
class_name FoodPatron
## Посетитель фуд-корта: очередь у лавки → заказ у окна → ждёт готовку у ВЫДАЧИ →
## садится «есть» → уходит (деспаун). Движение по навмешу (паттерн NPCAgent._step).
## Создаётся пулом FoodCourtManager по скрытой популярности лавок. Сеть — этап 5.

enum St { GO_QUEUE, IN_QUEUE, GO_ORDER, ORDERING, GO_PICKUP, WAIT_PICKUP, GO_TABLE, EATING, LEAVE }

@export var speed: float = 3.2

const SERVICE := 1.6    # сек у окна заказа
const COOK := 3.0       # сек готовки (ждёт у выдачи)
const EAT := 8.0        # сек ест

var stall: StallPOI = null
var state: int = St.GO_QUEUE
var _target: Vector3 = Vector3.ZERO
var _timer: float = 0.0
var _stuck_t: float = 0.0
var _grav: float = ProjectSettings.get_setting("physics/3d/default_gravity", 18.0)
var _nav: NavigationAgent3D
var _knock: Vector3 = Vector3.ZERO

func apply_knock(v: Vector3) -> void:
	_knock = v

func _ready() -> void:
	add_to_group("food_patron")
	add_to_group("knockable")
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.6
	var col := CollisionShape3D.new()
	col.shape = cap
	col.position = Vector3(0, 0.8, 0)
	add_child(col)
	var mesh := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.32
	cm.height = 1.6
	mesh.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.8, 0.7)   # посетители — бежевые
	mesh.material_override = mat
	mesh.position = Vector3(0, 0.8, 0)
	add_child(mesh)
	_nav = NavigationAgent3D.new()
	_nav.path_desired_distance = 0.6
	_nav.target_desired_distance = 0.6
	_nav.avoidance_enabled = false
	add_child(_nav)

func setup(s: StallPOI) -> void:
	stall = s
	state = St.GO_QUEUE
	_target = stall.queue_back_position()

func go_order(point: Vector3) -> void:
	state = St.GO_ORDER
	_target = point
	_stuck_t = 0.0

func _physics_process(delta: float) -> void:
	if _knock.length() > 0.3:
		velocity = _knock
		velocity.y = (velocity.y - _grav * delta) if not is_on_floor() else 0.0
		move_and_slide()
		_knock = _knock.move_toward(Vector3.ZERO, delta * 18.0)
		return
	if stall == null or not is_instance_valid(stall):
		queue_free()
		return
	match state:
		St.GO_QUEUE:
			_target = stall.queue_back_position()
			_step(_target, delta)
			_antistuck(_target, delta)
			if _near(_target):
				stall.join_queue(self)
				state = St.IN_QUEUE
		St.IN_QUEUE:
			_step(stall.queue_slot(stall.queue_index(self)), delta)
		St.GO_ORDER:
			_step(_target, delta)
			_antistuck(_target, delta)
			if _near(_target):
				state = St.ORDERING
				_timer = SERVICE
		St.ORDERING:
			_timer -= delta
			if _timer <= 0.0:
				stall.npc_ordered(self)
				_timer = COOK
				state = St.GO_PICKUP
				_target = stall.pickup_point()
		St.GO_PICKUP:
			_step(_target, delta)
			_antistuck(_target, delta)
			if _near(_target):
				state = St.WAIT_PICKUP
		St.WAIT_PICKUP:
			_step(_target, delta)
			_timer -= delta
			if _timer <= 0.0:
				state = St.GO_TABLE
				_target = stall.global_position + Vector3(randf_range(-6, 6), 0, 8)
		St.GO_TABLE:
			_step(_target, delta)
			_antistuck(_target, delta)
			if _near(_target):
				state = St.EATING
				_timer = EAT
		St.EATING:
			_timer -= delta
			if _timer <= 0.0:
				state = St.LEAVE
				_target = stall.global_position + Vector3(randf_range(-10, 10), 0, 18)
		St.LEAVE:
			_step(_target, delta)
			_antistuck(_target, delta)
			if _near(_target):
				queue_free()

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
	return Vector2(target.x - global_position.x, target.z - global_position.z).length() < 0.9

func _antistuck(target: Vector3, delta: float) -> void:
	var rv := get_real_velocity()
	if Vector2(rv.x, rv.z).length() < 0.3 and not _near(target):
		_stuck_t += delta
		if _stuck_t > 4.0:
			global_position = Vector3(target.x, global_position.y, target.z)
			_stuck_t = 0.0
	else:
		_stuck_t = 0.0
