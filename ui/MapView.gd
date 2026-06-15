extends Control
class_name MapView
## Схематичная карта парка (2D-отрисовка): река-кольцо, плаза, зоны, горки,
## подписи локаций, игрок («вы здесь») и приватные метки. Один виджет для
## большой карты (M) и миникарты. Лёгкая — примитивы, без второй 3D-камеры.
## interactive=true → ЛКМ метка, ПКМ убрать, колесо — зум.

@export var world_span: float = 92.0
@export var interactive: bool = false
@export var show_labels: bool = false

const ZONE_COLORS := {
	"klyk": Color(0.5, 0.7, 1.0), "delta": Color(1.0, 0.7, 0.4), "zero": Color(0.62, 0.62, 0.68),
}
const ZONE_NAMES := {
	"klyk": "Северный Клык", "delta": "Дельта", "zero": "Серый Пояс Зеро",
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
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				RunState.add_marker(map_to_world(mb.position))
			MOUSE_BUTTON_RIGHT:
				RunState.remove_marker_near(map_to_world(mb.position))
			MOUSE_BUTTON_WHEEL_UP:
				world_span = clampf(world_span * 0.9, 30.0, 150.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				world_span = clampf(world_span * 1.1, 30.0, 150.0)

func _draw() -> void:
	var s := _scale()
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.09, 0.12))
	draw_arc(world_to_map(Vector3.ZERO), 21.0 * s, 0.0, TAU, 64, Color(0.8, 0.2, 0.2, 0.7), 3.0)
	draw_circle(world_to_map(Vector3.ZERO), 12.0 * s, Color(0.25, 0.28, 0.34, 0.5))
	if show_labels:
		_label(font, world_to_map(Vector3.ZERO), "Центральный бассейн", Color(0.8, 0.9, 1.0))

	for z in get_tree().get_nodes_in_group("zone"):
		var zt := z as ZoneTracker
		if zt == null:
			continue
		var col: Color = ZONE_COLORS.get(zt.zone_id, Color.GRAY)
		var p := world_to_map(zt.global_position)
		draw_circle(p, 9.0 * s, Color(col.r, col.g, col.b, 0.35))
		if show_labels:
			_label(font, p, ZONE_NAMES.get(zt.zone_id, zt.zone_id), col)

	for sl in get_tree().get_nodes_in_group("slide"):
		var sp := world_to_map((sl as Node3D).global_position)
		draw_circle(sp, maxf(4.0, 1.6 * s), Color(0.5, 0.85, 1.0))
		if show_labels:
			_label(font, sp + Vector2(0, 16), "горка %s" % (sl as SlideRail).slide_id, Color(0.6, 0.85, 1.0))

	for m in RunState.markers:
		_draw_diamond(world_to_map(m), 6.0, Color(1.0, 0.9, 0.3))

	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var pl := players[0] as Node3D
		_draw_player(pl)
		if show_labels:
			_label(font, world_to_map(pl.global_position) + Vector2(0, 18), "вы здесь", Color(0.4, 1.0, 0.5))

func _label(font: Font, pos: Vector2, text: String, col: Color) -> void:
	draw_string(font, pos + Vector2(-60, -14), text, HORIZONTAL_ALIGNMENT_CENTER, 120, 13, col)

func _draw_player(p: Node3D) -> void:
	var mp := world_to_map(p.global_position)
	var fwd := -p.global_transform.basis.z
	var d2 := Vector2(fwd.x, fwd.z)
	d2 = d2.normalized() if d2.length() > 0.01 else Vector2.UP
	var perp := Vector2(-d2.y, d2.x)
	draw_colored_polygon(PackedVector2Array([
		mp + d2 * 11.0, mp - d2 * 7.0 + perp * 7.0, mp - d2 * 7.0 - perp * 7.0,
	]), Color(0.3, 1.0, 0.45))

func _draw_diamond(c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0),
	]), col)
