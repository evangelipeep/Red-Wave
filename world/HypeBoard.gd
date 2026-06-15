extends Node3D
## Табло Гула: 3D-вывеска в парке с популярностью всех горк по зонам и пометкой
## «горка дня». Помогает выбирать, куда идти (хайповая горка = длинная очередь).
## Обновляется при броске Гула (старт забега).

var _label: Label3D

func _ready() -> void:
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 44
	_label.pixel_size = 0.012
	_label.outline_size = 14
	_label.modulate = Color(1, 1, 1)
	_label.position = Vector3(0, 1.0, 0)
	add_child(_label)
	EventBus.run_planning_started.connect(_refresh)
	EventBus.run_started.connect(_refresh)
	_refresh()

func _refresh() -> void:
	var s := "— ТАБЛО ГУЛА —\n"
	for z in Slides.ZONES:
		s += "\n[%s]\n" % z
		for id in Slides.in_zone(z):
			var star := "  <— ГОРКА ДНЯ" if id == Hype.day_slide else ""
			s += "  %s : %d%s\n" % [id, int(Hype.gul.get(id, 0)), star]
	_label.text = s
