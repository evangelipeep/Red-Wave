extends CharacterBody3D
class_name PlayerController
## FPS-контроллер игрока (фаза 1): ходьба/бег/прыжок по земле + режим плавания.
## Управление: WASD — движение, Space — прыжок / всплытие в воде, Shift — бег,
## Ctrl — погружение (в воде), мышь — обзор, Esc — освободить/захватить курсор.
##
## Дизайн: бег сжигает вес (−1 кг / 400 м, GDD §5) через WeightSystem.add_run_distance().
## Вода вес НЕ меняет — в режиме плавания дистанция не считается.
## Скорость спуска с горок (вес→множитель) живёт в SlideRail, не здесь.

@export_group("Look")
@export var mouse_sensitivity: float = 0.0025
@export var pitch_min_deg: float = -89.0
@export var pitch_max_deg: float = 89.0

@export_group("Move")
@export var walk_speed: float = 4.0
@export var sprint_speed: float = 7.0
@export var swim_speed: float = 3.0
@export var jump_velocity: float = 6.0
@export var ground_accel: float = 12.0
@export var air_accel: float = 3.0
@export var swim_accel: float = 6.0

var swimming: bool = false
var riding: bool = false        # едем с горки — движением управляет SlideRail
var _rail: Node = null

@onready var _head: Node3D = $Head
@onready var _cam := $Head/Camera3D as CameraComfort
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _was_on_floor: bool = true
var _water_count: int = 0   # сколько водных зон сейчас перекрываем

func _ready() -> void:
	add_to_group("player")
	_ensure_inputs()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if has_node("WaterSensor"):
		var ws: Area3D = $WaterSensor
		ws.area_entered.connect(_on_water_entered)
		ws.area_exited.connect(_on_water_exited)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		var dx := -mm.relative.x * mouse_sensitivity
		var dy := -mm.relative.y * mouse_sensitivity
		if riding:
			# на спуске тело ведёт рейка — крутим только голову (свободный обзор)
			_head.rotation.y = clamp(_head.rotation.y + dx,
				deg_to_rad(-120.0), deg_to_rad(120.0))
		else:
			rotate_y(dx)
		_head.rotation.x = clamp(_head.rotation.x + dy,
			deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE \
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			else Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if riding:
		return          # позицию задаёт SlideRail через ride_to()
	if swimming:
		_swim(delta)
	else:
		_walk(delta)

func _walk(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	var moving := input != Vector2.ZERO
	var sprinting := Input.is_action_pressed("sprint") and moving
	var target_speed := sprint_speed if sprinting else walk_speed
	var accel := ground_accel if is_on_floor() else air_accel

	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	horiz = horiz.lerp(dir * target_speed, clamp(accel * delta, 0.0, 1.0))
	velocity.x = horiz.x
	velocity.z = horiz.z
	move_and_slide()

	# Бег сжигает вес (−1 кг / 400 м). Считаем только на земле.
	var dist := Vector2(velocity.x, velocity.z).length() * delta
	if is_on_floor() and dist > 0.0:
		WeightSystem.add_run_distance(dist)

	# Comfort: ощущение скорости + посадочный «клевок».
	var speed_ratio := Vector2(velocity.x, velocity.z).length() / sprint_speed
	_cam.update_motion(speed_ratio, is_on_floor(), delta, sprinting)
	if is_on_floor() and not _was_on_floor:
		_cam.land_kick()
	_was_on_floor = is_on_floor()

func _swim(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Плывём туда, куда смотрим (направление от камеры, с учётом наклона).
	var dir := _cam.global_transform.basis * Vector3(input.x, 0.0, input.y)
	if Input.is_action_pressed("jump"):
		dir.y += 1.0
	if Input.is_action_pressed("swim_down"):
		dir.y -= 1.0
	dir = dir.normalized()

	velocity = velocity.lerp(dir * swim_speed, clamp(swim_accel * delta, 0.0, 1.0))
	move_and_slide()
	_cam.update_motion(velocity.length() / swim_speed, false, delta, false)
	_was_on_floor = false

# --- Катание с горки (управляется SlideRail). ---
func mount_rail(rail: Node) -> void:
	riding = true
	_rail = rail
	swimming = false
	velocity = Vector3.ZERO

# Рейка вызывает каждый кадр: ставит тело на точку сплайна + кормит comfort скоростью.
func ride_to(t: Transform3D, speed_ratio: float, delta: float) -> void:
	global_transform = t
	_cam.update_motion(speed_ratio, false, delta, true)

func dismount(at: Transform3D) -> void:
	riding = false
	_rail = null
	global_position = at.origin + Vector3.UP * 0.5
	# выпрямляем тело по направлению съезда (только горизонталь), голову — прямо
	var flat := Vector3(-at.basis.z.x, 0.0, -at.basis.z.z)
	if flat.length() > 0.01:
		look_at(global_position + flat, Vector3.UP)
	_head.rotation.y = 0.0
	velocity = Vector3.ZERO

func _on_water_entered(area: Area3D) -> void:
	if area.is_in_group("water"):
		_water_count += 1
		swimming = true

func _on_water_exited(area: Area3D) -> void:
	if area.is_in_group("water"):
		_water_count = max(_water_count - 1, 0)
		if _water_count == 0:
			swimming = false

# --- Регистрация управления (физические клавиши). ---
# Делаем в коде, чтобы прототип работал без ручной настройки Input Map.
# Если действие уже задано в Project Settings → Input Map, не трогаем его.
func _ensure_inputs() -> void:
	_add_key("move_forward", KEY_W)
	_add_key("move_back", KEY_S)
	_add_key("move_left", KEY_A)
	_add_key("move_right", KEY_D)
	_add_key("jump", KEY_SPACE)
	_add_key("sprint", KEY_SHIFT)
	_add_key("swim_down", KEY_CTRL)

func _add_key(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if InputMap.action_get_events(action).is_empty():
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode
		InputMap.action_add_event(action, ev)
