extends Node3D
class_name NPCAgent
## Лёгкий NPC без физики: капсула, что двигается лёрпом по ключевым точкам.
## Цикл жизни: дойти до очереди → стоять в очереди → съехать (двигает SlideRail)
## → всплыть в бассейне → вылезти по лестнице → побродить → снова в очередь.

enum St { GO_QUEUE, IN_QUEUE, RIDING, IN_POOL, CLIMB, WANDER }

@export var speed: float = 3.5

var slide: SlideRail = null
var state: int = St.WANDER
var ride_t: float = 0.0          # прогресс спуска (двигает SlideRail)

var _target: Vector3
var _wander_timer: float = 0.0

func _ready() -> void:
	var mesh := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 1.7
	mesh.mesh = cap
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.from_hsv(randf(), 0.55, 0.9)
	mesh.material_override = mat
	mesh.position = Vector3(0, 0.9, 0)
	add_child(mesh)

func setup(s: SlideRail) -> void:
	slide = s
	global_position = Vector3(randf_range(-15.0, 15.0), 0.2, randf_range(-4.0, 16.0))
	_go_queue()

func _physics_process(delta: float) -> void:
	if slide == null:
		return
	match state:
		St.GO_QUEUE:
			_move(delta)
			if _arrived():
				slide.join_queue(self)
				state = St.IN_QUEUE
		St.IN_QUEUE:
			_target = slide.slot_position(slide.queue_index(self))
			_move(delta)
		St.RIDING:
			pass   # позицию задаёт SlideRail
		St.IN_POOL:
			_move(delta)
			if _arrived():
				state = St.CLIMB
				_target = slide.ladder_top()
		St.CLIMB:
			_move(delta)
			if _arrived():
				_wander()
		St.WANDER:
			_move(delta)
			_wander_timer -= delta
			if _arrived() or _wander_timer <= 0.0:
				_go_queue()

func _move(delta: float) -> void:
	global_position = global_position.move_toward(_target, speed * delta)

func _arrived() -> bool:
	return global_position.distance_to(_target) < 0.6

func _go_queue() -> void:
	state = St.GO_QUEUE
	_target = slide.queue_back_position()

func _wander() -> void:
	state = St.WANDER
	_wander_timer = randf_range(3.0, 7.0)
	_target = slide.wander_point()

# --- Вызывает SlideRail. ---
func begin_ride() -> void:
	state = St.RIDING
	ride_t = 0.0

func reached_pool(pos: Vector3) -> void:
	global_position = pos
	state = St.IN_POOL
	_target = slide.ladder_base()
