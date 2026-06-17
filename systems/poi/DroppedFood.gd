extends Node3D
class_name DroppedFood
## Поднос, оставленный игроком на полу фуд-корта. Другой игрок может подобрать (E).
## Бесхозный пропадает через 20 игровых минут (этап 4 — его убирает уборщик-NPC).
## Сетевая сущность с кросс-подбором — этап 5.

const DESPAWN_MIN := 20.0
const DAY_MINUTES := 720.0

var tray: Dictionary = {}
var _despawn_at: float = 1.0

func setup(t: Dictionary) -> void:
	tray = t
	_despawn_at = Clock.day_fraction + DESPAWN_MIN / DAY_MINUTES

func _ready() -> void:
	add_to_group("dropped_food")
	var col: Color = tray.get("color", Color.WHITE)
	var box := CSGBox3D.new()
	box.size = Vector3(0.5, 0.4, 0.5)
	box.position = Vector3(0, 0.25, 0)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	box.material = m
	add_child(box)
	var lb := Label3D.new()
	lb.text = "еда (E)"
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.font_size = 28
	lb.pixel_size = 0.011
	lb.outline_size = 6
	lb.modulate = col.lightened(0.4)
	lb.position = Vector3(0, 0.8, 0)
	add_child(lb)

func _process(_delta: float) -> void:
	if Clock.day_fraction >= _despawn_at:
		queue_free()
