extends Node3D
class_name CharacterRig
## ============================================================================
##  CharacterRig — переиспользуемая «заготовка персонажа» (силуэт + анимация).
##  Цель: один компонент и для игрока (вид от 1-го лица), и для NPC (вид со
##  стороны). Это ВРЕМЕННЫЙ силуэт из примитивов под тун-стиль (Look.mat) —
##  по его пропорциям рисуется модель в Blender, а потом он заменяется.
##
##  ДВА РЕЖИМА АНИМАЦИИ:
##   • Процедурный (по умолчанию): суставы-Node3D крутятся в коде — ожидание,
##     ходьба, бег, прыжок, спуск с горки, плавание. Ничего кейфреймить не надо,
##     работает сразу. Это фолбэк для силуэта и для NPC.
##   • Клипы модели: если задан animation_player_path (AnimationPlayer
##     импортированной модели), риг ПРОИГРЫВАЕТ клипы по имени состояния
##     (clip_idle/walk/run/jump/ride/swim), а процедурку выключает.
##
##  ВИД ОТ 1-го ЛИЦА: голова получает cast_shadow = SHADOWS_ONLY — её не видно
##  своей камерой (не смотришь изнутри черепа), но ТЕНЬ падает с головой. Тело,
##  руки и ноги видно, когда смотришь вниз и на спуске с горки.
##
##  ПРЕДМЕТ В РУКАХ: крепи к tray_anchor() и зови set_carry(true) — руки выйдут
##  вперёд «нести предмет», и он будет в кадре.
##
##  ТОЛЩИНА ОТ ВЕСА: set_weight01(0..1) раздувает торс/таз (живот) — игрок зовёт
##  его от WeightSystem (>90 кг = толстый), дополняя «косолапую» камеру.
##
##  КАК подсунуть модель из Blender: импортируй .glb (скелет+меши+анимации),
##  удали узел "Placeholder", вставь модель внутрь рига и укажи
##  animation_player_path; перенаправь head_anchor()/hand_anchor_r()/tray_anchor()
##  на свои кости (BoneAttachment3D). Пропорции силуэта правятся в инспекторе.
## ============================================================================

enum Pose { IDLE, WALK, RUN, JUMP, RIDE, SWIM }

# --- Пропорции (правь в инспекторе или через make(); по ним рисуешь модель) ---
@export_group("Пропорции")
@export var total_height: float = 1.7      # рост (м) — ступни в 0, макушка ~ height
@export var build: float = 1.0             # «комплекция»: 0.8 худой … 1.4 толстый
@export var head_scale: float = 1.0        # размер головы (чиби-стиль = 1.5+)

@export_group("Цвета")
@export var skin_color: Color = Color(0.85, 0.68, 0.55)
@export var outfit_color: Color = Color(0.45, 0.30, 0.55)
@export var shoe_color: Color = Color(0.15, 0.15, 0.18)

@export_group("Вид от первого лица")
@export var first_person: bool = false     # голова → SHADOWS_ONLY (своя тень с головой)

@export_group("Модель из Blender (необязательно)")
## Готовая модель (.glb как PackedScene). Если задана — риг ВМЕСТО силуэта вставляет её,
## сам находит AnimationPlayer и якоря (по именам Head/HandR/TrayAnchor, иначе пустышки).
## Пусто → строится процедурный силуэт-заглушка (работает сразу, без модели).
@export var model_scene: PackedScene

@export_group("Анимации модели (если есть клипы)")
## Укажи AnimationPlayer импортированной модели — тогда риг играет КЛИПЫ по имени
## состояния, а процедурная анимация-силуэт выключается (фолбэк остаётся у NPC).
@export var animation_player_path: NodePath
@export var clip_idle: String = "idle"
@export var clip_walk: String = "walk"
@export var clip_run: String = "run"
@export var clip_jump: String = "jump"
@export var clip_ride: String = "ride"
@export var clip_swim: String = "swim"

# --- Суставы (их крутит процедурная анимация) ---
var _hips: Node3D
var _spine: Node3D
var _chest: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _fore_l: Node3D
var _fore_r: Node3D
var _hand_l: Node3D
var _hand_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _shin_l: Node3D
var _shin_r: Node3D
var _foot_l: Node3D
var _foot_r: Node3D
var _tray: Node3D                 # якорь предмета «в руках»

var _head_meshes: Array[MeshInstance3D] = []    # голова/глаза — SHADOWS_ONLY в 1-м лице
var _fp_hide: Array[MeshInstance3D] = []        # шея/торс — тоже прячем от своей камеры (упираются в лицо)
var _belly_meshes: Array[MeshInstance3D] = []   # таз+торс — раздуваем от веса (живот)
var _hip_h: float = 0.85
var _phase: float = 0.0          # фаза шага (ходьба/бег/плавание)
var _idle_t: float = 0.0         # время для дыхания в покое
var _carry: bool = false         # держим предмет (руки вперёд)

# Клипы модели (если заданы) — иначе процедурка.
var _anim: AnimationPlayer = null
var _use_clips: bool = false
var _clip_state: String = ""

# Покоящиеся повороты рук (плечи слегка в стороны, локти чуть согнуты).
const ARM_REST_Z := 0.14
const FORE_REST_X := -0.12

# --- Фабрика: создать готовый риг одной строкой. ---
static func make(p_height: float, p_skin: Color, p_outfit: Color,
		p_first_person: bool = false, p_build: float = 1.0,
		p_head_scale: float = 1.0) -> CharacterRig:
	var r := CharacterRig.new()
	r.total_height = p_height
	r.skin_color = p_skin
	r.outfit_color = p_outfit
	r.first_person = p_first_person
	r.build = p_build
	r.head_scale = p_head_scale
	return r

func _ready() -> void:
	_build()
	# Явно указанный AnimationPlayer имеет приоритет; иначе берём авто-найденный из модели.
	if not animation_player_path.is_empty():
		_anim = get_node_or_null(animation_player_path) as AnimationPlayer
	_use_clips = _anim != null
	# Покой кейфреймим только для процедурного силуэта (у модели — свои клипы/статика).
	if not _use_clips and model_scene == null:
		_pose_idle(0.0)

# ===========================================================================
#  ПОСТРОЕНИЕ: модель из Blender (если задана) ИЛИ процедурный силуэт-заглушка.
# ===========================================================================
func _build() -> void:
	if model_scene != null:
		_build_from_model()
	else:
		_build_placeholder()

# Вставляем готовую модель: ищем AnimationPlayer и якоря (Head/HandR/TrayAnchor).
func _build_from_model() -> void:
	var inst := model_scene.instantiate()
	inst.name = "Model"
	add_child(inst)
	var ap := _find_anim(inst)
	if ap != null:
		_anim = ap
	_tray = _find_named(inst, ["TrayAnchor", "Tray"])
	if _tray == null:
		_tray = _make_anchor(Vector3(0, total_height * 0.55, -total_height * 0.13))
	_head = _find_named(inst, ["Head", "head", "mixamorig:Head"])
	if _head == null:
		_head = _make_anchor(Vector3(0, total_height * 0.92, 0))
	_hand_r = _find_named(inst, ["HandR", "hand_r", "mixamorig:RightHand"])
	if _hand_r == null:
		_hand_r = _tray
	# 1-е лицо: прячем меши головы (своя башка не загораживает обзор), тень остаётся.
	if first_person:
		for m in _collect_meshes(_head):
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r != null:
			return r
	return null

func _find_named(root: Node, names: Array) -> Node3D:
	for nm in names:
		var f := root.find_child(str(nm), true, false)
		if f is Node3D:
			return f
	return null

func _make_anchor(pos: Vector3) -> Node3D:
	var a := Node3D.new()
	a.position = pos
	add_child(a)
	return a

func _collect_meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n == null:
		return out
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_collect_meshes(c))
	return out

func _build_placeholder() -> void:
	var root := Node3D.new()
	root.name = "Placeholder"
	add_child(root)

	var h := total_height
	_hip_h = 0.50 * h
	var chest_h := 0.82 * h
	var spine_len := chest_h - _hip_h
	var sh_w := 0.12 * h * build
	var leg_w := 0.085 * h * build
	var th_len := 0.245 * h
	var sh_len := 0.235 * h
	var ua_len := 0.16 * h
	var fa_len := 0.15 * h
	var neck_len := 0.05 * h
	var head_r := 0.085 * h * head_scale
	var skin := skin_color
	var cloth := outfit_color

	# Таз + спина (наклоняется в суставе _spine). Таз и торс раздуваются от веса.
	_hips = _joint(root, Vector3(0, _hip_h, 0))
	_belly_meshes.append(_box(_hips, Vector3(0.20 * h * build, 0.13 * h, 0.15 * h * build), Vector3(0, -0.02 * h, 0), cloth))
	_spine = _joint(_hips, Vector3.ZERO)
	var torso := _box(_spine, Vector3(0.26 * h * build, spine_len, 0.17 * h * build), Vector3(0, spine_len * 0.5, 0), cloth)
	_belly_meshes.append(torso)
	_fp_hide.append(torso)   # торс упирается в камеру 1-го лица — прячем
	_chest = _joint(_spine, Vector3(0, spine_len, 0))

	# Шея + голова (в 1-м лице голова и шея — SHADOWS_ONLY, иначе чёрный outline в лицо).
	_fp_hide.append(_capsule(_chest, neck_len, 0.045 * h, Vector3(0, neck_len * 0.5, 0), skin))
	_head = _joint(_chest, Vector3(0, neck_len, 0))
	_head_meshes.append(_sphere(_head, head_r, Vector3(0, head_r, 0), skin))
	_head_meshes.append(_eye(_head, Vector3(0.38 * head_r, head_r * 1.05, -head_r * 0.82)))
	_head_meshes.append(_eye(_head, Vector3(-0.38 * head_r, head_r * 1.05, -head_r * 0.82)))

	# Руки (плечи чуть в стороны — ARM_REST_Z).
	_arm_l = _joint(_chest, Vector3(sh_w, -0.03 * h, 0)); _arm_l.rotation.z = ARM_REST_Z
	_capsule(_arm_l, ua_len, 0.05 * h * build, Vector3(0, -ua_len * 0.5, 0), skin)
	_fore_l = _joint(_arm_l, Vector3(0, -ua_len, 0)); _fore_l.rotation.x = FORE_REST_X
	_capsule(_fore_l, fa_len, 0.042 * h * build, Vector3(0, -fa_len * 0.5, 0), skin)
	_hand_l = _joint(_fore_l, Vector3(0, -fa_len, 0))
	_box(_hand_l, Vector3(0.06 * h, 0.07 * h, 0.05 * h), Vector3(0, -0.035 * h, 0), skin)

	_arm_r = _joint(_chest, Vector3(-sh_w, -0.03 * h, 0)); _arm_r.rotation.z = -ARM_REST_Z
	_capsule(_arm_r, ua_len, 0.05 * h * build, Vector3(0, -ua_len * 0.5, 0), skin)
	_fore_r = _joint(_arm_r, Vector3(0, -ua_len, 0)); _fore_r.rotation.x = FORE_REST_X
	_capsule(_fore_r, fa_len, 0.042 * h * build, Vector3(0, -fa_len * 0.5, 0), skin)
	_hand_r = _joint(_fore_r, Vector3(0, -fa_len, 0))
	_box(_hand_r, Vector3(0.06 * h, 0.07 * h, 0.05 * h), Vector3(0, -0.035 * h, 0), skin)

	# Ноги.
	_leg_l = _joint(_hips, Vector3(leg_w, 0, 0))
	_capsule(_leg_l, th_len, 0.075 * h * build, Vector3(0, -th_len * 0.5, 0), cloth)
	_shin_l = _joint(_leg_l, Vector3(0, -th_len, 0))
	_capsule(_shin_l, sh_len, 0.06 * h * build, Vector3(0, -sh_len * 0.5, 0), skin)
	_foot_l = _joint(_shin_l, Vector3(0, -sh_len, 0))
	_box(_foot_l, Vector3(0.08 * h, 0.05 * h, 0.16 * h), Vector3(0, -0.02 * h, -0.04 * h), shoe_color)

	_leg_r = _joint(_hips, Vector3(-leg_w, 0, 0))
	_capsule(_leg_r, th_len, 0.075 * h * build, Vector3(0, -th_len * 0.5, 0), cloth)
	_shin_r = _joint(_leg_r, Vector3(0, -th_len, 0))
	_capsule(_shin_r, sh_len, 0.06 * h * build, Vector3(0, -sh_len * 0.5, 0), skin)
	_foot_r = _joint(_shin_r, Vector3(0, -sh_len, 0))
	_box(_foot_r, Vector3(0.08 * h, 0.05 * h, 0.16 * h), Vector3(0, -0.02 * h, -0.04 * h), shoe_color)

	# Якорь «в руках» — впереди груди (туда крепится поднос/предмет).
	_tray = _joint(_chest, Vector3(0, -0.12 * h, -0.22 * h))

	if first_person:
		_head_shadow_only()

# ===========================================================================
#  ПУБЛИЧНЫЙ API для контроллеров (игрок и NPC).
# ===========================================================================

## Земная анимация: сама выбирает покой/ходьбу/бег по скорости.
func animate_ground(speed: float, run_speed: float, grounded: bool, delta: float) -> void:
	if _use_clips:
		var n := clip_idle
		if not grounded:
			n = clip_jump
		elif speed >= run_speed * 0.85:
			n = clip_run
		elif speed >= 0.25:
			n = clip_walk
		_play_clip(n)
		return
	if _hips == null:
		return
	if not grounded:
		_pose_jump()
	elif speed < 0.25:
		_pose_idle(delta)
	else:
		_pose_walk(speed, maxf(run_speed, 0.1), delta)
	if _carry:
		_apply_carry_arms()

## Поза спуска с горки (видно ноги, когда смотришь вниз).
func animate_ride(_delta: float) -> void:
	if _use_clips:
		_play_clip(clip_ride)
		return
	if _hips == null:
		return
	_pose_ride()

## Плавание (гребки руками + работа ног).
func animate_swim(speed: float, delta: float) -> void:
	if _use_clips:
		_play_clip(clip_swim)
		return
	if _hips == null:
		return
	_pose_swim(speed, delta)

## Держим предмет в руках (руки выходят вперёд «нести предмет»).
func set_carry(active: bool) -> void:
	_carry = active

## Толщина от веса: 0 — норма, 1 — максимум (живот). Игрок зовёт от WeightSystem.
func set_weight01(t: float) -> void:
	t = clampf(t, 0.0, 1.0)
	if _use_clips:
		scale = Vector3(1.0 + t * 0.25, 1.0, 1.0 + t * 0.25)   # модель: лёгкое раздувание
		return
	var s := Vector3(1.0 + t * 0.6, 1.0 + t * 0.12, 1.0 + t * 0.65)
	for m in _belly_meshes:
		m.scale = s

## Якорь для предмета «в руках» (крепи сюда MeshInstance подноса/предмета).
func tray_anchor() -> Node3D:
	return _tray

func hand_anchor_r() -> Node3D:
	return _hand_r

func head_anchor() -> Node3D:
	return _head

# ===========================================================================
#  Клипы модели.
# ===========================================================================
func _play_clip(n: String) -> void:
	if _anim == null or n == "" or not _anim.has_animation(n):
		return
	if _clip_state == n:
		return
	_clip_state = n
	_anim.play(n, 0.15)

# ===========================================================================
#  ПОЗЫ (повороты суставов; значения в радианах, абсолютные = покой + смещение).
# ===========================================================================
func _pose_idle(delta: float) -> void:
	_idle_t += delta
	var b := sin(_idle_t * 1.5)
	_hips.position.y = _hip_h + b * 0.004
	_spine.rotation = Vector3(b * 0.015, 0, 0)
	_head.rotation = Vector3(b * 0.02, 0, 0)
	_arm_l.rotation = Vector3(b * 0.04, 0, ARM_REST_Z)
	_arm_r.rotation = Vector3(-b * 0.04, 0, -ARM_REST_Z)
	_fore_l.rotation = Vector3(FORE_REST_X, 0, 0)
	_fore_r.rotation = Vector3(FORE_REST_X, 0, 0)
	_straighten_legs()

func _pose_walk(speed: float, run_speed: float, delta: float) -> void:
	var ratio := clampf(speed / run_speed, 0.0, 1.3)
	_phase += delta * lerpf(7.0, 11.0, clampf(ratio, 0.0, 1.0))
	var amp := clampf(ratio, 0.25, 1.0) * 0.6        # размах ног растёт со скоростью
	var arm_amp := amp * 0.85
	var sw := sin(_phase)
	_hips.position.y = _hip_h + absf(cos(_phase)) * 0.02 * amp
	_spine.rotation = Vector3(0.04, -sw * 0.05, 0)   # лёгкий наклон + раскачка корпуса
	_head.rotation = Vector3.ZERO
	# Ноги в противофазе; колено сгибается на заднем замахе.
	_leg_l.rotation = Vector3(sw * amp, 0, 0)
	_leg_r.rotation = Vector3(-sw * amp, 0, 0)
	_shin_l.rotation = Vector3(minf(0.0, sw) * amp * 1.5, 0, 0)
	_shin_r.rotation = Vector3(minf(0.0, -sw) * amp * 1.5, 0, 0)
	_foot_l.rotation = Vector3.ZERO
	_foot_r.rotation = Vector3.ZERO
	# Руки в противофазе ногам.
	_arm_l.rotation = Vector3(-sw * arm_amp, 0, ARM_REST_Z)
	_arm_r.rotation = Vector3(sw * arm_amp, 0, -ARM_REST_Z)
	_fore_l.rotation = Vector3(FORE_REST_X - 0.2, 0, 0)
	_fore_r.rotation = Vector3(FORE_REST_X - 0.2, 0, 0)

func _pose_jump() -> void:
	_hips.position.y = _hip_h
	_spine.rotation = Vector3(0.08, 0, 0)
	_head.rotation = Vector3.ZERO
	_leg_l.rotation = Vector3(0.5, 0, 0)
	_leg_r.rotation = Vector3(0.4, 0, 0)
	_shin_l.rotation = Vector3(-0.7, 0, 0)
	_shin_r.rotation = Vector3(-0.6, 0, 0)
	_foot_l.rotation = Vector3.ZERO
	_foot_r.rotation = Vector3.ZERO
	_arm_l.rotation = Vector3(-0.7, 0, ARM_REST_Z + 0.2)
	_arm_r.rotation = Vector3(-0.7, 0, -ARM_REST_Z - 0.2)
	_fore_l.rotation = Vector3(FORE_REST_X, 0, 0)
	_fore_r.rotation = Vector3(FORE_REST_X, 0, 0)

func _pose_ride() -> void:
	# Сидим в «бублике»: корпус слегка откинут, ноги вынесены вперёд, руки держат.
	_hips.position.y = _hip_h
	_spine.rotation = Vector3(-0.25, 0, 0)
	_head.rotation = Vector3(0.1, 0, 0)
	_leg_l.rotation = Vector3(1.35, 0, 0.06)
	_leg_r.rotation = Vector3(1.35, 0, -0.06)
	_shin_l.rotation = Vector3(-0.5, 0, 0)
	_shin_r.rotation = Vector3(-0.5, 0, 0)
	_foot_l.rotation = Vector3.ZERO
	_foot_r.rotation = Vector3.ZERO
	_arm_l.rotation = Vector3(0.9, 0, 0.1)
	_arm_r.rotation = Vector3(0.9, 0, -0.1)
	_fore_l.rotation = Vector3(-0.4, 0, 0)
	_fore_r.rotation = Vector3(-0.4, 0, 0)

func _pose_swim(speed: float, delta: float) -> void:
	_phase += delta * lerpf(2.5, 5.0, clampf(speed / 3.0, 0.0, 1.0))
	var sw := sin(_phase)
	_hips.position.y = _hip_h
	_spine.rotation = Vector3(0.4, 0, 0)             # корпус вперёд (почти горизонтально)
	_head.rotation = Vector3(-0.2, 0, 0)
	# Гребки руками по кругу.
	_arm_l.rotation = Vector3(-0.3 + sw * 0.7, 0, 0.5)
	_arm_r.rotation = Vector3(-0.3 - sw * 0.7, 0, -0.5)
	_fore_l.rotation = Vector3(-0.5, 0, 0)
	_fore_r.rotation = Vector3(-0.5, 0, 0)
	# Работа ног (флаттер).
	_leg_l.rotation = Vector3(sw * 0.3, 0, 0)
	_leg_r.rotation = Vector3(-sw * 0.3, 0, 0)
	_shin_l.rotation = Vector3(0.2, 0, 0)
	_shin_r.rotation = Vector3(0.2, 0, 0)
	_foot_l.rotation = Vector3.ZERO
	_foot_r.rotation = Vector3.ZERO

func _straighten_legs() -> void:
	_leg_l.rotation = Vector3.ZERO
	_leg_r.rotation = Vector3.ZERO
	_shin_l.rotation = Vector3.ZERO
	_shin_r.rotation = Vector3.ZERO
	_foot_l.rotation = Vector3.ZERO
	_foot_r.rotation = Vector3.ZERO

# Держим предмет: руки вперёд к подносу (перекрывает покой/ходьбу для рук).
func _apply_carry_arms() -> void:
	_arm_l.rotation = Vector3(0.7, 0, 0.18)
	_arm_r.rotation = Vector3(0.7, 0, -0.18)
	_fore_l.rotation = Vector3(-1.1, 0, -0.12)
	_fore_r.rotation = Vector3(-1.1, 0, 0.12)

# ===========================================================================
#  Хелперы построения примитивов (всё в тун-стиле через Look.mat).
# ===========================================================================
func _joint(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	n.position = pos
	return n

func _capsule(parent: Node3D, length: float, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = maxf(length, radius * 2.01)
	m.mesh = c
	m.position = pos
	m.material_override = Look.mat(color)
	parent.add_child(m)
	return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.position = pos
	m.material_override = Look.mat(color)
	parent.add_child(m)
	return m

func _sphere(parent: Node3D, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	m.mesh = s
	m.position = pos
	m.material_override = Look.mat(color)
	parent.add_child(m)
	return m

func _eye(parent: Node3D, pos: Vector3) -> MeshInstance3D:
	return _sphere(parent, total_height * 0.018 * head_scale, pos, Color(0.08, 0.06, 0.1))

# 1-е лицо: голова/глаза/шея/торс — только тень (не видно своей башки и не упираемся
# чёрным контуром в камеру), но тень падает целиком. Руки/ноги/таз остаются видимыми.
func _head_shadow_only() -> void:
	for m in _head_meshes:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	for m in _fp_hide:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
