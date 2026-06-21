extends Node
## ============================================================================
##  Look — фабрика материалов и единая палитра «тун-стиля» (Wind Waker).
##  Это autoload (см. project.godot): доступен из любого скрипта как `Look`.
##
##  ЗАЧЕМ: чтобы весь парк выглядел в одном стиле, материалы НЕ создаём руками,
##  а просим у фабрики:
##      some_csg.material        = Look.mat(Color(...))
##      some_mesh.material_override = Look.mat(Look.WOOD)
##  Тогда одним вызовом получаем тун-шейдинг + чёрный контур. Прозрачность
##  включается автоматически, если у цвета alpha < 1.
##
##  КАК добавить новый объект в стиле: вместо `StandardMaterial3D.new()` пиши
##  `Look.mat(Color(...))`. Хочешь свечение (вывеска/неон) — `Look.emissive(...)`.
##
##  ПАЛИТРА: держись цветов из раздела «Палитра» — единый набор важнее деталей.
##  Хочешь сменить настроение всего парка — крути константы стиля и палитру ниже.
##  Полный гайд: см. ART_STYLE.md в корне проекта.
## ============================================================================

# --- Шейдеры (грузятся один раз при старте) --------------------------------
const _TOON    := preload("res://assets/shaders/toon.gdshader")        # непрозрачный
const _TOON_A  := preload("res://assets/shaders/toon_alpha.gdshader")  # прозрачный
const _OUTLINE := preload("res://assets/shaders/outline.gdshader")     # контур

# --- Глобальные настройки стиля (правь и смотри, как меняется ВЕСЬ парк) ----
const BANDS         := 3.0                       # ступеней света 2..5: меньше = «мультяшнее»
const OUTLINE_WIDTH := 0.04                      # толщина контура в метрах
const OUTLINE_COLOR := Color(0.06, 0.05, 0.09)   # цвет контура (почти чёрный)

# --- Палитра парка (8–12 базовых цветов; зови цвет по роли, а не по RGB) ----
const SKY    := Color(0.62, 0.80, 0.98)   # небо/лёд
const WATER  := Color(0.20, 0.55, 0.95)   # обычная вода/синий
const WAVE   := Color(0.80, 0.10, 0.10)   # «Красная Волна» (фирменный красный)
const SAND   := Color(0.92, 0.85, 0.62)   # песок/светлый пол
const STONE  := Color(0.55, 0.55, 0.62)   # камень/бетон
const WOOD   := Color(0.60, 0.45, 0.32)   # дерево
const LEAF   := Color(0.35, 0.70, 0.40)   # зелень/растения
const METAL  := Color(0.45, 0.48, 0.55)   # металл/конструкции
const ACCENT := Color(1.00, 0.70, 0.30)   # тёплый акцент (зона Дельта)
const DARK   := Color(0.20, 0.20, 0.26)   # тёмное (мусорка, тени-объекты)

# ---------------------------------------------------------------------------
#  ГЛАВНАЯ фабрика: тун-материал (+ контур).
#   color       — базовый цвет; alpha < 1 → автоматически прозрачный шейдер
#   outline     — вешать ли чёрный контур (по умолчанию да; у прозрачных — нет)
#   transparent — принудительно прозрачный, даже если alpha == 1 (редко нужно)
# ---------------------------------------------------------------------------
func mat(color: Color, outline: bool = true, transparent: bool = false) -> ShaderMaterial:
	var is_transparent := transparent or color.a < 0.999
	var m := ShaderMaterial.new()
	m.shader = _TOON_A if is_transparent else _TOON
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("bands", BANDS)
	# Контур к прозрачным поверхностям не идёт (выглядит грязно), поэтому and not.
	if outline and not is_transparent:
		m.next_pass = _outline_pass()
	return m

# Тун-материал со СВЕЧЕНИЕМ (вывески, неон, лучи прицела, киоски).
#   energy — сила свечения (0 = выкл; 2..4 = заметно светится)
func emissive(color: Color, energy: float = 2.0, outline: bool = false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _TOON
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("bands", BANDS)
	m.set_shader_parameter("emission_color", color)
	m.set_shader_parameter("emission_energy", energy)
	if outline:
		m.next_pass = _outline_pass()
	return m

# Отдельный пасс-контур (используется как next_pass). Вручную звать обычно не нужно.
func _outline_pass() -> ShaderMaterial:
	var o := ShaderMaterial.new()
	o.shader = _OUTLINE
	o.set_shader_parameter("width", OUTLINE_WIDTH)
	o.set_shader_parameter("color", OUTLINE_COLOR)
	return o
