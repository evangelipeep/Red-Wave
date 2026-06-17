extends Node3D
class_name DroppedFood
## Поднос, оставленный игроком на полу фуд-корта. Другой игрок может подобрать (E).
## Жизненным циклом (спавн/подбор/уборка/деспаун) управляет FoodCourtManager —
## в коопе он сетевой (host-authority), поэтому здесь только данные + визуал.

var tray: Dictionary = {}
var spawned_at: float = 0.0     # доля дня, когда уронили (для уборщика/деспауна)
var net_id: int = -1            # общий id сущности в коопе

func setup(t: Dictionary) -> void:
	tray = t
	spawned_at = Clock.day_fraction

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
