extends Area3D
class_name SpaPOI
## Зона релакса спа-комплекса: пока локальный игрок внутри — тошнота спадает (лечит),
## организм успокаивается. У каждого вида свой бонус:
##   onsen     — горячий источник: лечит быстрее всех;
##   jacuzzi   — джакузи: лечит + пузырьки (быстрый релакс);
##   sauna_fin — финская сауна: лечит + потеешь (сжигаешь калории/вес);
##   banya     — русская баня: лечит + на выходе бодрит (буст скорости).

@export var spa_type: String = "onsen"

var _inside: bool = false
var _heal_accum: float = 0.0

func _ready() -> void:
	add_to_group("spa")
	_build_visual()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 3.0, 4.0)
	cs.shape = box
	cs.position = Vector3(0, 1.5, 0)
	add_child(cs)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)

func _heal_rate() -> float:
	match spa_type:
		"onsen": return 2.0
		"jacuzzi": return 1.5
		_: return 1.0   # сауна/баня

func _title() -> String:
	match spa_type:
		"onsen": return "ОНСЭН"
		"jacuzzi": return "ДЖАКУЗИ"
		"sauna_fin": return "САУНА"
		"banya": return "БАНЯ"
		_: return "СПА"

func _color() -> Color:
	match spa_type:
		"onsen": return Color(0.55, 0.8, 0.95)
		"jacuzzi": return Color(0.3, 0.85, 0.8)
		"sauna_fin": return Color(0.75, 0.55, 0.35)
		"banya": return Color(0.7, 0.35, 0.3)
		_: return Color(0.7, 0.7, 0.8)

func _on_enter(body: Node3D) -> void:
	if body is PlayerController:
		_inside = true
		_heal_accum = 0.0
		EventBus.toast.emit("%s: расслабляешься… тошнота спадает." % _title())

func _on_exit(body: Node3D) -> void:
	if not (body is PlayerController):
		return
	_inside = false
	if spa_type == "banya":
		PlayerBuffs.apply_effect("caffeine", 3.0)   # баня взбодрила
		EventBus.toast.emit("Баня взбодрила — скорость ×2 на время!")

func _process(delta: float) -> void:
	if not _inside:
		return
	_heal_accum += _heal_rate() * delta
	while _heal_accum >= 1.0:
		_heal_accum -= 1.0
		if RunState.dizziness > 0:
			RunState.add_dizziness(-1)   # delta<0 — без тревожных тостов
	if spa_type == "sauna_fin":
		WeightSystem.burn(GameConstants.CAL_WALK * 0.6 * delta)   # потеешь — уходит вес

func _build_visual() -> void:
	var col := _color()
	if spa_type == "onsen" or spa_type == "jacuzzi":
		# Купель: каменный бортик + цветная «вода».
		var rim := CSGCylinder3D.new()
		rim.radius = 2.2
		rim.height = 0.8
		rim.position = Vector3(0, 0.4, 0)
		rim.use_collision = true
		rim.material = _mat(Color(0.5, 0.5, 0.55))
		rim.add_to_group("navsource")
		add_child(rim)
		var water := CSGCylinder3D.new()
		water.radius = 1.9
		water.height = 0.5
		water.position = Vector3(0, 0.65, 0)
		water.material = _mat(col, true)
		add_child(water)
		_add_steam(1.0)   # пар/пузырьки над водой
	else:
		# Сауна/баня: деревянная изба.
		var hut := CSGBox3D.new()
		hut.size = Vector3(4.0, 3.0, 4.0)
		hut.position = Vector3(0, 1.5, 0)
		hut.use_collision = true
		hut.material = _mat(col)
		hut.add_to_group("navsource")
		add_child(hut)
		var roof := CSGBox3D.new()
		roof.size = Vector3(4.6, 0.4, 4.6)
		roof.position = Vector3(0, 3.1, 0)
		roof.material = _mat(col.darkened(0.3))
		add_child(roof)
		_add_steam(3.4)   # пар из бани/сауны
	var label := Label3D.new()
	label.text = _title()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
	label.pixel_size = 0.018
	label.outline_size = 10
	label.modulate = col.lightened(0.4)
	label.position = Vector3(0, 3.7, 0)
	add_child(label)

# Лёгкий пар, медленно поднимающийся вверх.
func _add_steam(height: float) -> void:
	var steam := GPUParticles3D.new()
	steam.amount = 14
	steam.lifetime = 2.8
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(1.4, 0.1, 1.4)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.7
	pm.gravity = Vector3(0, 0.25, 0)
	pm.scale_min = 0.4
	pm.scale_max = 0.9
	pm.color = Color(1, 1, 1, 0.22)
	steam.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 0.7)
	var qm := StandardMaterial3D.new()
	qm.albedo_color = Color(1, 1, 1, 0.22)
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = qm
	steam.draw_pass_1 = quad
	steam.position = Vector3(0, height, 0)
	add_child(steam)

# Тун-материал через фабрику Look (см. autoload/Look.gd).
func _mat(c: Color, transparent: bool = false) -> ShaderMaterial:
	return Look.mat(c, not transparent, transparent)
