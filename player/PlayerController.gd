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
@export var swim_rise_speed: float = 3.5     # всплытие/погружение (Space/Ctrl)
@export var swim_idle_sink: float = 0.8      # лёгкое погружение в покое
@export var swim_vertical_accel: float = 8.0 # ниже = дольше скользим по инерции под водой
@export var splash_sound: AudioStream        # звук брызг (назначь .wav/.ogg в инспекторе)

var swimming: bool = false
var _water_surface_y: float = 0.0           # уровень поверхности текущей воды
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
	# Глубина «головы»: >0 — голова под водой, <0 — над поверхностью.
	var depth := _water_surface_y - (global_position.y + 0.9)

	# Горизонталь — туда, куда смотрим.
	var dir := _cam.global_transform.basis * Vector3(input.x, 0.0, input.y)
	var horiz := Vector3(dir.x, 0.0, dir.z)
	if horiz.length() > 1.0:
		horiz = horiz.normalized()
	velocity.x = lerp(velocity.x, horiz.x * swim_speed, clampf(swim_accel * delta, 0.0, 1.0))
	velocity.z = lerp(velocity.z, horiz.z * swim_speed, clampf(swim_accel * delta, 0.0, 1.0))

	# Вертикаль (как в Minecraft): Space — всплывать, Ctrl — нырять, иначе медленно тонуть.
	# Когда всплываешь к поверхности и продолжаешь жать Space — мягко выходишь из воды
	# (уносишь вверх скорость ≤ swim_rise_speed), без катапульты.
	var target_vy := -swim_idle_sink
	if Input.is_action_pressed("jump"):
		target_vy = swim_rise_speed
	elif Input.is_action_pressed("swim_down"):
		target_vy = -swim_rise_speed
	# Над поверхностью без всплытия не «вылетаем» — мягко тянем вниз.
	if depth < 0.0 and not Input.is_action_pressed("jump"):
		target_vy = minf(target_vy, -0.5)
	velocity.y = move_toward(velocity.y, target_vy, swim_vertical_accel * delta)

	move_and_slide()
	_cam.update_motion(Vector2(velocity.x, velocity.z).length() / swim_speed, false, delta, false)
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

func dismount(at: Transform3D, exit_velocity: Vector3 = Vector3.ZERO) -> void:
	riding = false
	_rail = null
	global_position = at.origin + Vector3.UP * 0.5
	# выпрямляем тело по направлению съезда (только горизонталь), голову — прямо
	var flat := Vector3(-at.basis.z.x, 0.0, -at.basis.z.z)
	if flat.length() > 0.01:
		look_at(global_position + flat, Vector3.UP)
	_head.rotation.y = 0.0
	velocity = exit_velocity   # сохраняем инерцию спуска — влетаем в воду со скоростью

func _on_water_entered(area: Area3D) -> void:
	if area.is_in_group("water"):
		_water_count += 1
		swimming = true
		_water_surface_y = area.get_meta("surface_y", global_position.y)
		# Брызги при входе: мощнее от скорости влёта и веса (тяжелее = сильнее/громче).
		var entry_speed := velocity.length()
		if entry_speed > 3.0:
			var weight_norm := WeightSystem.kg / GameConstants.WEIGHT_START
			var strength := clampf(entry_speed * 0.18 * weight_norm, 0.4, 4.0)
			_spawn_splash(strength)

func _on_water_exited(area: Area3D) -> void:
	if area.is_in_group("water"):
		_water_count = max(_water_count - 1, 0)
		if _water_count == 0:
			swimming = false

# Брызги от входа в воду. strength ~ скорость × вес (0.4..4.0).
func _spawn_splash(strength: float) -> void:
	var host := get_tree().current_scene
	if host == null:
		return
	var splash_pos := Vector3(global_position.x, _water_surface_y, global_position.z)

	var p := GPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = clampi(int(16.0 * strength), 8, 140)
	p.lifetime = 0.9
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 40.0
	pm.initial_velocity_min = 1.5 * strength
	pm.initial_velocity_max = 3.5 * strength
	pm.gravity = Vector3(0, -12.0, 0)
	pm.scale_min = 0.08
	pm.scale_max = 0.22
	pm.color = Color(0.9, 0.15, 0.15)
	p.process_material = pm
	var drop := SphereMesh.new()
	drop.radius = 0.07
	drop.height = 0.14
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.9, 0.15, 0.15)
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = dm
	p.draw_pass_1 = drop
	host.add_child(p)
	p.global_position = splash_pos
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.3).timeout.connect(p.queue_free)

	# Звук (громче с силой удара) — только если назначен ассет.
	if splash_sound:
		var a := AudioStreamPlayer3D.new()
		a.stream = splash_sound
		a.volume_db = lerpf(-12.0, 6.0, clampf(strength / 4.0, 0.0, 1.0))
		host.add_child(a)
		a.global_position = splash_pos
		a.play()
		a.finished.connect(a.queue_free)

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
