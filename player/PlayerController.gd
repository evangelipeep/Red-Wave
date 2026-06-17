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
@export var water_drag: float = 1.5          # сопротивление воды (ниже = дольше скользишь по инерции)
@export var river_drift: float = 2.5         # сила течения ленивой реки
@export var splash_sound: AudioStream        # звук брызг (назначь .wav/.ogg в инспекторе)

var swimming: bool = false
var _water_surface_y: float = 0.0           # уровень поверхности текущей воды
var _in_river: bool = false                 # в ленивой реке (есть течение)
var _river_flow: Vector3 = Vector3.ZERO     # направление течения текущего русла
var _river_center: Vector3 = Vector3.ZERO   # центр кольца реки (для счёта кругов)
var _river_count: int = 0
var _river_angle_accum: float = 0.0         # накопленный угол вокруг центра
var _river_last_angle: float = 0.0
var riding: bool = false        # едем с горки — движением управляет SlideRail
var _rail: Node = null

@onready var _head: Node3D = $Head
@onready var _cam := $Head/Camera3D as CameraComfort
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _was_on_floor: bool = true
var _water_count: int = 0   # сколько водных зон сейчас перекрываем

var _active: bool = false   # игрок управляем только во время забега (не на планировании)
var _map_open: bool = false # открыта карта M — управление заморожено (без паузы мира)
var _ui_modal: bool = false # открыто модальное окно (меню лавки/диалог) — заморозка
var _ping_cd: float = 0.0   # кулдаун пинга

# Палитра цветов игроков для пингов/меток (MARKER_COLORS = 4).
const PING_COLORS := [
	Color(0.3, 0.6, 1.0), Color(1.0, 0.4, 0.3),
	Color(0.4, 1.0, 0.5), Color(1.0, 0.85, 0.3),
]

func _ready() -> void:
	add_to_group("player")
	_ensure_inputs()
	EventBus.run_started.connect(_on_run_started)
	EventBus.run_planning_started.connect(_on_run_planning)
	Clock.day_finished.connect(_on_run_planning)   # конец дня — тоже заморозка
	EventBus.map_opened.connect(_on_map_opened)
	EventBus.ui_modal.connect(func(open: bool): _ui_modal = open)
	if has_node("WaterSensor"):
		var ws: Area3D = $WaterSensor
		ws.area_entered.connect(_on_water_entered)
		ws.area_exited.connect(_on_water_exited)

func _on_run_started() -> void:
	_active = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_run_planning() -> void:
	_active = false
	velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# Карта открыта — стоим на месте (мир продолжает идти), управление заморожено.
func _on_map_opened(open: bool) -> void:
	_map_open = open
	if open:
		velocity = Vector3.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if not _active or _map_open or _ui_modal:
		return
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
	# --- Фуд-корт: инвентарь подносов, еда, взаимодействие ---
	elif event.is_action_pressed("inv_1"):
		RunState.select_slot(0)
	elif event.is_action_pressed("inv_2"):
		RunState.select_slot(1)
	elif event.is_action_pressed("inv_3"):
		RunState.select_slot(2)
	elif event.is_action_pressed("inv_4"):
		RunState.select_slot(3)
	elif event.is_action_pressed("eat_food"):
		RunState.eat_from_slot(RunState.selected_slot)
	elif event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("throw_food"):
		_throw_food()
	elif event.is_action_pressed("toilet"):
		if not WeightSystem.toilet():
			EventBus.toast.emit("Туалет недоступен — раз в 3 часа (ещё %.1f ч)"
				% WeightSystem.toilet_ready_in_hours())
	elif event.is_action_pressed("ping"):
		_do_ping()

# Взаимодействие (E): заказать/забрать у лавки, подобрать выброшенную еду.
# Логику лавок/еды подключит этап 3 (StallPOI/выброшенная еда сами слушают присутствие).
func _interact() -> void:
	EventBus.interact_pressed.emit()

# Выброс выбранного подноса (G): у мусорки — с подтверждением (этап 3), иначе уронить на пол.
func _throw_food() -> void:
	if RunState.selected_slot < 0:
		return
	EventBus.throw_food_pressed.emit()

func _physics_process(delta: float) -> void:
	if _ping_cd > 0.0:
		_ping_cd -= delta
	if not _active or _map_open or _ui_modal:
		return          # планирование/карта/меню — игрок заморожен (мир продолжает идти)
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
		WeightSystem.burn(GameConstants.CAL_JUMP)   # прыжок сжигает калории — не почитеришь

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	var moving := input != Vector2.ZERO
	var sprinting := Input.is_action_pressed("sprint") and moving and not RunState.run_blocked
	var target_speed := sprint_speed if sprinting else walk_speed
	target_speed *= PlayerBuffs.move_speed_mult()   # кофеин ×2 / тяжесть ×0.8 (еда)
	var accel := ground_accel if is_on_floor() else air_accel

	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	horiz = horiz.lerp(dir * target_speed, clamp(accel * delta, 0.0, 1.0))
	velocity.x = horiz.x
	velocity.z = horiz.z
	move_and_slide()

	# Активность сжигает калории: бег жжёт больше ходьбы (прыжок учтён выше).
	if is_on_floor():
		var ground_speed := Vector2(velocity.x, velocity.z).length()
		if ground_speed > 0.3:
			var rate := GameConstants.CAL_RUN if sprinting else GameConstants.CAL_WALK
			WeightSystem.burn(rate * delta)

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

	# Сопротивление воды гасит инерцию ПЛАВНО — влетаешь со скоростью и скользишь.
	var k := clampf(water_drag * delta, 0.0, 1.0)
	velocity = velocity.lerp(Vector3.ZERO, k)

	# Горизонталь: управление добавляет силу (равновесная скорость ≈ swim_speed).
	var dir := _cam.global_transform.basis * Vector3(input.x, 0.0, input.y)
	var horiz := Vector3(dir.x, 0.0, dir.z)
	if horiz.length() > 1.0:
		horiz = horiz.normalized()
	velocity.x += horiz.x * swim_speed * water_drag * delta
	velocity.z += horiz.z * swim_speed * water_drag * delta

	# Течение ленивой реки — тащит вдоль русла (flow_dir) + считаем круги.
	if _in_river:
		velocity.x += _river_flow.x * river_drift * water_drag * delta
		velocity.z += _river_flow.z * river_drift * water_drag * delta
		var a := atan2(global_position.z - _river_center.z, global_position.x - _river_center.x)
		_river_angle_accum += wrapf(a - _river_last_angle, -PI, PI)
		_river_last_angle = a
		if absf(_river_angle_accum) >= TAU:
			_river_angle_accum -= TAU * signf(_river_angle_accum)
			RunState.add_lap()

	# Вертикаль (как в Minecraft): Space — всплывать, Ctrl — нырять, иначе лёгкое погружение.
	# Всплыл к поверхности и держишь Space → мягко выходишь (уносишь ≤ swim_rise_speed).
	if Input.is_action_pressed("jump"):
		velocity.y += swim_rise_speed * water_drag * delta
	elif Input.is_action_pressed("swim_down"):
		velocity.y -= swim_rise_speed * water_drag * delta
	else:
		velocity.y -= swim_idle_sink * water_drag * delta
	if depth < 0.0 and not Input.is_action_pressed("jump"):
		velocity.y = minf(velocity.y, -0.3)

	move_and_slide()

	# Плавание сжигает мало калорий (только при движении).
	var swim_spd := Vector2(velocity.x, velocity.z).length()
	if swim_spd > 0.3:
		WeightSystem.burn(GameConstants.CAL_SWIM * delta)
	_cam.update_motion(swim_spd / swim_speed, false, delta, false)
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
	if area.is_in_group("river"):
		_river_count += 1
		_in_river = true
		_river_flow = area.get_meta("flow_dir", Vector3.ZERO)
		_river_center = area.get_meta("river_center", Vector3.ZERO)
		_river_last_angle = atan2(global_position.z - _river_center.z, global_position.x - _river_center.x)

func _on_water_exited(area: Area3D) -> void:
	if area.is_in_group("water"):
		_water_count = max(_water_count - 1, 0)
		if _water_count == 0:
			swimming = false
	if area.is_in_group("river"):
		_river_count = max(_river_count - 1, 0)
		if _river_count == 0:
			_in_river = false
			_river_angle_accum = 0.0

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
	# Фуд-корт: взаимодействие/еда/инвентарь
	_add_key("interact", KEY_E)      # заказать у лавки / забрать / подобрать
	_add_key("eat_food", KEY_F)      # съесть блюдо из активного слота
	_add_key("throw_food", KEY_G)    # выбросить активный поднос
	_add_key("inv_1", KEY_1)
	_add_key("inv_2", KEY_2)
	_add_key("inv_3", KEY_3)
	_add_key("inv_4", KEY_4)
	_add_key("toilet", KEY_T)
	_add_key("map", KEY_M)
	_add_mouse("ping", MOUSE_BUTTON_MIDDLE)

func _add_mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if InputMap.action_get_events(action).is_empty():
		var ev := InputEventMouseButton.new()
		ev.button_index = button
		InputMap.action_add_event(action, ev)

# --- Контекстный пинг (СКМ): метка в мире цветом игрока (DESIGN FROZEN). ---
func _do_ping() -> void:
	if _ping_cd > 0.0:
		return
	var from := _cam.global_position
	var to := from - _cam.global_transform.basis.z * 60.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	_ping_cd = GameConstants.PING_CD
	var pos: Vector3 = hit["position"]
	var ctx := _classify_ping(pos)
	_spawn_marker(pos, ctx)
	EventBus.ping_made.emit(Net.local_id(), pos, ctx)

func _classify_ping(pos: Vector3) -> String:
	var nearest := _nearest_slide(pos)
	if nearest != null and pos.distance_to(nearest.global_position) < 12.0:
		return "к горке %s" % nearest.slide_id
	var r := Vector2(pos.x, pos.z).length()
	if r > 16.0 and r < 27.0:
		return "встречаемся на реке"
	return "сюда"

func _nearest_slide(pos: Vector3) -> SlideRail:
	var best: SlideRail = null
	var bd := 1e9
	for s in get_tree().get_nodes_in_group("slide"):
		var sr := s as SlideRail
		if sr == null:
			continue
		var d := pos.distance_to(sr.global_position)
		if d < bd:
			bd = d
			best = sr
	return best

func _spawn_marker(pos: Vector3, ctx: String) -> void:
	var host := get_tree().current_scene
	if host == null:
		return
	var col: Color = PING_COLORS[(Net.local_id() - 1) % PING_COLORS.size()]
	var root := Node3D.new()
	host.add_child(root)
	root.global_position = pos

	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.12
	cyl.height = 3.0
	beam.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	beam.material_override = mat
	beam.position = Vector3(0, 1.5, 0)
	root.add_child(beam)

	var label := Label3D.new()
	label.text = ctx
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.pixel_size = 0.01
	label.outline_size = 8
	label.modulate = col
	label.position = Vector3(0, 3.3, 0)
	root.add_child(label)

	get_tree().create_timer(GameConstants.PING_LIFE).timeout.connect(root.queue_free)

func _add_key(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if InputMap.action_get_events(action).is_empty():
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode
		InputMap.action_add_event(action, ev)
