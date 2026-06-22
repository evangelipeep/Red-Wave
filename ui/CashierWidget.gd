extends VBoxContainer
class_name CashierWidget
## Кассир-вампир (2D): лицо-эмодзи + касса + реплика. На react() «вбивает» заказ —
## пунч кассы 🧾 + кивок головы + реплика. Общий виджет для меню лавки и магазина.
## Настройка до add_child: clerk_name / clerk_face.

var clerk_name: String = "Кассир Дракулеску"
var clerk_face: String = "🧛"

var _face: Label
var _register: Label
var _say: Label

const ADD_LINES := ["*тык-тык* вношу…", "Записал, кровопийца.", "Ещё что-нибудь?", "*клац-клац*"]
const REM_LINES := ["Убираю позицию…", "Передумали? Бывает.", "*бэкспейс*", "Минус один."]

func _ready() -> void:
	custom_minimum_size = Vector2(210, 460)
	var head := Label.new()
	head.add_theme_font_size_override("font_size", 20)
	head.modulate = Color(0.85, 0.7, 1.0)
	head.text = "КАССА"
	add_child(head)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.08, 0.14, 0.95)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", sb)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(panel)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	_face = Label.new()
	_face.add_theme_font_size_override("font_size", 96)
	_face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_face.text = clerk_face
	v.add_child(_face)
	var namel := Label.new()
	namel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	namel.modulate = Color(0.8, 0.8, 0.9)
	namel.text = clerk_name
	v.add_child(namel)
	_register = Label.new()
	_register.add_theme_font_size_override("font_size", 40)
	_register.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_register.text = "🧾"
	v.add_child(_register)
	_say = Label.new()
	_say.add_theme_font_size_override("font_size", 14)
	_say.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_say.custom_minimum_size.x = 180
	_say.modulate = Color(0.7, 0.95, 0.8)
	_say.text = "Что желаете, голубчик?"
	v.add_child(_say)

# «Вбивает»/«убирает» позицию: пунч кассы + кивок головы + реплика.
func react(added: bool) -> void:
	if _register == null:
		return
	_register.pivot_offset = _register.size * 0.5
	_register.scale = Vector2(1.35, 1.35)
	_register.modulate = Color(1.0, 0.9, 0.4)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_register, "scale", Vector2.ONE, 0.28)
	tw.parallel().tween_property(_register, "modulate", Color.WHITE, 0.28)
	_face.pivot_offset = _face.size * 0.5
	_face.scale = Vector2(1.0, 0.88)   # кивок
	var tw2 := create_tween()
	tw2.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw2.tween_property(_face, "scale", Vector2.ONE, 0.2)
	_say.text = (ADD_LINES if added else REM_LINES).pick_random()

func say(text: String) -> void:
	if _say != null:
		_say.text = text
