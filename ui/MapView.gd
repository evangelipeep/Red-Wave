extends Control
class_name MapView
## Схематичная карта парка (2D-отрисовка): река-кольцо, плаза, зоны, горки,
## игрок (стрелка) и приватные метки. Используется и как большая карта (M),
## и как миникарта. Лёгкая — рисуется примитивами, без второй 3D-камеры.
## interactive=true → ЛКМ ставит метку, ПКМ убирает ближайшую.

@export var world_span: float = 92.0   # сколько метров мира влезает по меньшей стороне
@export var interactive: bool = false

const ZONE_COLORS := {
	"klyk": Color(0.5, 0.7, 1.0),
	"delta": Color(1.0, 0.7, 0.4),
	"zero": Color(0.62, 0.62, 0.68),
}

func _process(_delta: float) -> void:
	queue_redraw()

func _scale() -> float:
	return minf(size.x, size.y) / world_span

func world_to_map(w: Vector3) -> Vector2:
	return size * 0.5 + Vector2(w.x, w.z) * _scale()

func map_to_world(p: Vector2) -> Vector3:
	var d := (p - size * 0.5) / _scale()
	return Vector3(d.x, 0.0, d.y)

func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			RunState.add_marker(map_to_world(mb.position))
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			RunState.remove_marker_near(map_to_world(mb.position))

func _draw() -> void:
	var s := _scale()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.09, 0.11))
	# Река-кольцо и плаза.
	draw_arc(world_to_map(Vector3.ZERO), 21.0 * s, 0.0, TAU, 64, Color(0.8, 0.2, 0.2, 0.7), 3.0)
	draw_circle(world_to_map(Vector3.ZERO), 12.0 * s, Color(0.3, 0.3, 0.34, 0.5))
	# Зоны.
	for z in get_tree().get_nodes_in_group("zone"):
		var zt := z as ZoneTracker
		if zt == null:
			continue
		var col: Color = ZONE_COLORS.get(zt.zone_id, Color.GRAY)
		draw_circle(world_to_map(zt.global_position), 9.0 * s, Color(col.r, col.g, col.b, 0.35))
	# Горки.
	for sl in get_tree().get_nodes_in_group("slide"):
		draw_circle(world_to_map((sl as Node3D).global_position), maxf(4.0, 1.6 * s), Color(0.5, 0.85, 1.0))
	# Приватные метки.
	for m in RunState.markers:
		_draw_diamond(world_to_map(m), 6.0, Color(1.0, 0.9, 0.3))
	# Игрок (стрелка по направлению взгляда).
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		_draw_player((players[0] as Node3D))

func _draw_player(p: Node3D) -> void:
	var mp := world_to_map(p.global_position)
	var fwd := -p.global_transform.basis.z
	var d2 := Vector2(fwd.x, fwd.z)
	d2 = d2.normalized() if d2.length() > 0.01 else Vector2.UP
	var perp := Vector2(-d2.y, d2.x)
	var pts := PackedVector2Array([mp + d2 * 10.0, mp - d2 * 6.0 + perp * 6.0, mp - d2 * 6.0 - perp * 6.0])
	draw_colored_polygon(pts, Color(0.3, 1.0, 0.45))

func _draw_diamond(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	draw_colored_polygon(pts, col)
