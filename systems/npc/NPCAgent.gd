extends CharacterBody3D
class_name NPCAgent
## NPC с коллизией (не призрак): ходит по земле через move_and_slide, упирается в
## игрока и друг друга. Цикл: дойти до очереди → стоять → (горка ведёт вниз) →
## вылезти сбоку по лесенке → бродить → снова в очередь. Во время спуска/вылезания
## коллизия выключена (едет по сплайну).

enum St { GO_QUEUE, IN_QUEUE, RIDING, EXIT, WANDER }

@export var speed: float = 3.5

var slide: SlideRail = null
var state: int = St.WANDER
var ride_t: float = 0.0
var _target: Vector3 = Vector3.ZERO
var _wander_timer: float = 0.0
var _stuck_t: float = 0.0
var _grav: float = ProjectSettings.get_setting("physics/3d/default_gravity", 18.0)
var _col: CollisionShape3D

func _ready() -> void:
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	_col = CollisionShape3D.new()
	_col.shape = cap
	_col.position = Vector3(0, 0.9, 0)
	add_child(_col)
	var mesh := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.35
	cm.height = 1.7
	mesh.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.from_hsv(randf(), 0.55, 0.9)
	mesh.material_override = mat
	mesh.position = Vector3(0, 0.9, 0)
	add_child(mesh)

func setup(s: SlideRail) -> void:
	slide = s
	global_position = Vector3(randf_range(-12.0, 12.0), 1.0, randf_range(-2.0, 14.0))
	_go_queue()

func _physics_process(delta: float) -> void:
	if slide == null:
		return
	match state:
		St.RIDING, St.EXIT:
			return   # позицию задаёт SlideRail (коллизия выключена)
		St.GO_QUEUE:
			var qb := slide.queue_back_position()
			_step(qb, delta)
			_antistuck(qb, delta)
			if _near(qb):
				slide.join_queue(self)
				state = St.IN_QUEUE
		St.IN_QUEUE:
			# Стоять за впереди стоящим — это нормально (без антистака).
			_step(slide.slot_position(slide.queue_index(self)), delta)
		St.WANDER:
			_step(_target, delta)
			_antistuck(_target, delta)
			_wander_timer -= delta
			if _near(_target) or _wander_timer <= 0.0:
				_go_queue()

func _step(target: Vector3, delta: float) -> void:
	var flat := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	if flat.length() > 0.5:
		var dir := flat.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)
	velocity.y = (velocity.y - _grav * delta) if not is_on_floor() else 0.0
	move_and_slide()

func _near(target: Vector3) -> bool:
	return Vector2(target.x - global_position.x, target.z - global_position.z).length() < 0.85

# Аварийное освобождение, если NPC упёрся в геометрию и не двигается.
func _antistuck(target: Vector3, delta: float) -> void:
	var rv := get_real_velocity()
	if Vector2(rv.x, rv.z).length() < 0.3 and not _near(target):
		_stuck_t += delta
		if _stuck_t > 4.0:
			global_position = Vector3(target.x, global_position.y, target.z)
			_stuck_t = 0.0
	else:
		_stuck_t = 0.0

func _go_queue() -> void:
	state = St.GO_QUEUE
	_target = slide.queue_back_position()

func _wander() -> void:
	state = St.WANDER
	_wander_timer = randf_range(3.0, 7.0)
	_target = slide.wander_point()

# --- Управляется SlideRail. ---
func begin_ride() -> void:
	state = St.RIDING
	ride_t = 0.0
	_col.disabled = true

func begin_exit() -> void:
	state = St.EXIT
	ride_t = 0.0

func end_cycle() -> void:
	_col.disabled = false
	_wander()
