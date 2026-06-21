extends Area3D
class_name ReceptionPOI
## Ресепшн в раздевалке: E — взять доп.желание (чужое, кто не смог прийти в аквапарк).
## Выполнил — очки (+SIDE_OK), провалил к финалу — штраф (−SIDE_FAIL). Берёшь — отвечаешь.

const MAX_SIDE := 3

var _inside: bool = false

func _ready() -> void:
	add_to_group("poi_reception")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8.0, 3.0, 5.0)
	cs.shape = box
	cs.position = Vector3(0, 1.5, 0)
	add_child(cs)
	var desk := CSGBox3D.new()
	desk.size = Vector3(6.0, 1.1, 2.5)
	desk.position = Vector3(0, 0.55, 0)
	desk.use_collision = true
	desk.material = Look.mat(Look.ACCENT)
	desk.add_to_group("navsource")
	add_child(desk)
	var label := Label3D.new()
	label.text = "РЕСЕПШН\n(E — доп.желание)"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 44
	label.pixel_size = 0.013
	label.outline_size = 9
	label.modulate = Color(1.0, 0.7, 0.4)
	label.position = Vector3(0, 2.6, 0)
	add_child(label)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	EventBus.interact_pressed.connect(_on_interact)

func _on_enter(b: Node3D) -> void:
	if b is PlayerController:
		_inside = true

func _on_exit(b: Node3D) -> void:
	if b is PlayerController:
		_inside = false

func _on_interact() -> void:
	if not _inside:
		return
	if RunState.side_quests.size() >= MAX_SIDE:
		EventBus.toast.emit("Больше доп.желаний не дают (взято %d)." % RunState.side_quests.size())
		return
	var atom: Dictionary = QuestGenerator.generate_personal()[0]
	atom["_paid"] = false
	RunState.side_quests.append(atom)
	EventBus.toast.emit("Взято доп.желание: «%s». Выполнишь +%d, провалишь %d." % [
		str(atom.get("name", "?")), GameConstants.SIDE_OK, GameConstants.SIDE_FAIL])
