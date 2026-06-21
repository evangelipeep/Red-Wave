extends Area3D
class_name ShowerPOI
## Душевая в раздевалке: пока стоишь под душем — тошнота понемногу спадает, освежает
## и слегка бодрит (короткий буст скорости на входе).

var _inside: bool = false
var _heal: float = 0.0

func _ready() -> void:
	add_to_group("shower")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 2.6, 2.2)
	cs.shape = box
	cs.position = Vector3(0, 1.3, 0)
	add_child(cs)
	# Кабинка душа (голубая) + «лейка».
	var stall := CSGBox3D.new()
	stall.size = Vector3(2.4, 2.8, 2.4)
	stall.position = Vector3(0, 1.4, 0)
	stall.use_collision = false
	stall.material = Look.mat(Color(0.4, 0.7, 0.95, 0.5), false, true)
	add_child(stall)
	var head := CSGCylinder3D.new()
	head.radius = 0.25
	head.height = 0.2
	head.position = Vector3(0, 2.7, 0)
	head.material = Look.mat(Look.METAL)
	add_child(head)
	var label := Label3D.new()
	label.text = "ДУШ"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.pixel_size = 0.012
	label.outline_size = 8
	label.modulate = Color(0.6, 0.85, 1.0)
	label.position = Vector3(0, 3.2, 0)
	add_child(label)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)

func _on_enter(body: Node3D) -> void:
	if body is PlayerController:
		_inside = true
		_heal = 0.0
		PlayerBuffs.apply_effect("caffeine", 1.5)   # освежает — короткий бодрый эффект
		EventBus.toast.emit("Душ освежает — тошнота спадает.")

func _on_exit(body: Node3D) -> void:
	if body is PlayerController:
		_inside = false

func _process(delta: float) -> void:
	if not _inside:
		return
	_heal += 1.0 * delta
	while _heal >= 1.0:
		_heal -= 1.0
		if RunState.dizziness > 0:
			RunState.add_dizziness(-1)
