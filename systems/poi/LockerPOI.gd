extends Area3D
class_name LockerPOI
## Шкафчики в раздевалке. Подходишь — напоминает твой номер; сюда позже ляжет телефон
## (на горки с ним нельзя — храни в шкафчике, как в жизни). Хранилище — этап с телефоном.

var _cd: float = 0.0

func _ready() -> void:
	add_to_group("poi_locker")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5.0, 3.0, 2.5)
	cs.shape = box
	cs.position = Vector3(0, 1.5, 0)
	add_child(cs)
	# Банк зелёных шкафчиков (сетка дверок).
	var bank := CSGBox3D.new()
	bank.size = Vector3(4.4, 2.4, 0.8)
	bank.position = Vector3(0, 1.2, 0)
	bank.use_collision = true
	bank.material = Look.mat(Look.LEAF)
	bank.add_to_group("navsource")
	add_child(bank)
	var label := Label3D.new()
	label.text = "ШКАФЧИКИ"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.pixel_size = 0.012
	label.outline_size = 8
	label.modulate = Look.LEAF.lightened(0.4)
	label.position = Vector3(0, 2.8, 0)
	add_child(label)
	body_entered.connect(_on_enter)

func _process(delta: float) -> void:
	if _cd > 0.0:
		_cd -= delta

func _on_enter(body: Node3D) -> void:
	if not (body is PlayerController) or _cd > 0.0:
		return
	_cd = 4.0
	EventBus.toast.emit("Ваш шкафчик № %d — здесь храните вещи (телефон — позже)." % RunState.locker_number)
