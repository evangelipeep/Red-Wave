extends CharacterBody3D
class_name NPCAgent
## Умный посетитель горок с типом поведения (за ним интересно наблюдать):
##   TOUR    — катается ПОДРЯД по всем горкам;
##   POPULAR — только по популярным (высокий Гул);
##   CASUAL  — 1–2 спуска, потом в театр или поплавать по реке, и снова.
## Движение пока прямое (move_and_slide) + анти-стак; NavMesh сгладит позже (в плане).

enum St { GO_QUEUE, IN_QUEUE, GO_BOARD, RIDING, EXIT, GO_THEATER, AT_THEATER, GO_RIVER, AT_RIVER }
enum Behavior { TOUR, POPULAR, CASUAL }

@export var speed: float = 3.5

var slide: SlideRail = null          # текущая целевая горка
var behavior: int = Behavior.TOUR
var state: int = St.GO_QUEUE
var ride_t: float = 0.0

var _all_slides: Array = []
var _slide_idx: int = 0
var _ride_count: int = 0
var _target: Vector3 = Vector3.ZERO
var _loiter_t: float = 0.0
var _stuck_t: float = 0.0
var _grav: float = ProjectSettings.get_setting("physics/3d/default_gravity", 18.0)
var _col: CollisionShape3D
var _nav: NavigationAgent3D
var _knock: Vector3 = Vector3.ZERO

func apply_knock(v: Vector3) -> void:
	_knock = v

func _ready() -> void:
	add_to_group("knockable")
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
	mesh.material_override = Look.mat(_behavior_color())
	mesh.position = Vector3(0, 0.9, 0)
	add_child(mesh)
	_nav = NavigationAgent3D.new()
	_nav.path_desired_distance = 0.6
	_nav.target_desired_distance = 0.6
	_nav.avoidance_enabled = false
	add_child(_nav)

func setup(b: int) -> void:
	behavior = b
	_all_slides = get_tree().get_nodes_in_group("slide")
	if _all_slides.is_empty():
		return
	_slide_idx = randi() % _all_slides.size()
	slide = _all_slides[_slide_idx]
	global_position = slide.wander_point()
	_go_queue()

func _behavior_color() -> Color:
	match behavior:
		Behavior.TOUR: return Color(0.3, 0.8, 1.0)     # любитель всего — голубой
		Behavior.POPULAR: return Color(1.0, 0.5, 0.3)  # за хайпом — оранжевый
		_: return Color(0.6, 0.9, 0.5)                 # расслабленный — зелёный

func _physics_process(delta: float) -> void:
	if _knock.length() > 0.3 and state != St.RIDING and state != St.EXIT:
		velocity = _knock
		velocity.y = (velocity.y - _grav * delta) if not is_on_floor() else 0.0
		move_and_slide()
		_knock = _knock.move_toward(Vector3.ZERO, delta * 18.0)
		return
	if slide == null:
		return
	match state:
		St.RIDING, St.EXIT:
			return   # позицию задаёт SlideRail
		St.GO_QUEUE:
			var qb := slide.queue_back_position()
			_step(qb, delta)
			_antistuck(qb, delta)
			if _near(qb):
				slide.join_queue(self)
				state = St.IN_QUEUE
		St.IN_QUEUE:
			_step(slide.slot_position(slide.queue_index(self)), delta)
		St.GO_BOARD:
			_step(_target, delta)
			_antistuck(_target, delta)
			if _near(_target):
				slide.npc_board(self)
		St.GO_THEATER, St.GO_RIVER:
			_step(_target, delta)
			_antistuck(_target, delta)
			if _near(_target):
				state = (St.AT_THEATER if state == St.GO_THEATER else St.AT_RIVER)
				_loiter_t = randf_range(5.0, 10.0)
		St.AT_THEATER:
			_loiter_t -= delta
			if _loiter_t <= 0.0:
				_decide_next()
		St.AT_RIVER:
			# Лёгкое «плавание» — дрейф вдоль реки.
			_step(_target, delta)
			_loiter_t -= delta
			if _loiter_t <= 0.0:
				_decide_next()

func _step(target: Vector3, delta: float) -> void:
	# Идём по навмешу (обход препятствий); без навмеша агент вернёт прямую к цели.
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

func _go_queue() -> void:
	state = St.GO_QUEUE
	_target = slide.queue_back_position()
	_stuck_t = 0.0

# Куда дальше после заезда — зависит от типа поведения.
func _decide_next() -> void:
	if _all_slides.is_empty():
		return
	match behavior:
		Behavior.TOUR:
			_slide_idx = (_slide_idx + 1) % _all_slides.size()
			slide = _all_slides[_slide_idx]
			_go_queue()
		Behavior.POPULAR:
			slide = _pick_popular()
			_go_queue()
		Behavior.CASUAL:
			if _ride_count < 2:
				slide = _all_slides[randi() % _all_slides.size()]
				_go_queue()
			else:
				_ride_count = 0
				if randf() < 0.5:
					_go_to(St.GO_THEATER, "poi_theater")
				else:
					_go_to(St.GO_RIVER, "river")

func _pick_popular() -> SlideRail:
	var hot: Array = []
	for s in _all_slides:
		if int(Hype.gul.get((s as SlideRail).slide_id, 50)) >= 60:
			hot.append(s)
	if hot.is_empty():
		hot = _all_slides
	return hot[randi() % hot.size()]

func _go_to(go_state: int, group: String) -> void:
	var nodes := get_tree().get_nodes_in_group(group)
	if nodes.is_empty():
		_go_queue()
		return
	state = go_state
	_target = (nodes[randi() % nodes.size()] as Node3D).global_position
	_stuck_t = 0.0

# --- Управляется SlideRail. ---
func go_board(target: Vector3) -> void:
	state = St.GO_BOARD
	_target = target
	_stuck_t = 0.0

func begin_ride() -> void:
	state = St.RIDING
	ride_t = 0.0
	_col.disabled = true

func begin_exit() -> void:
	state = St.EXIT
	ride_t = 0.0

func end_cycle() -> void:
	_col.disabled = false
	_ride_count += 1
	_decide_next()
