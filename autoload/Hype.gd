extends Node
## Автолоад: Гул (популярность). Один бросок на старте забега с ограничениями §10.
## gul[slide_id] ∈ [20..99]; ровно одна горка дня (>=90); в каждой зоне есть >=60 и <=50;
## горки <50 минимум в двух зонах; сумма Гула зоны не дальше 25% от средней.

var gul: Dictionary = {}
var day_slide: String = ""

func roll(rng_seed: int = -1) -> void:
	var rng := RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()

	for attempt in range(3000):
		var g := {}
		for id in Slides.ids():
			g[id] = rng.randi_range(20, 99)
		if not _valid(g):
			continue
		gul = g
		for id in g:
			if g[id] >= 90:
				day_slide = id
				break
		return
	# крайний fallback (не должен достигаться)
	gul = {}
	for id in Slides.ids():
		gul[id] = 50
	gul[Slides.ids()[0]] = 95
	day_slide = Slides.ids()[0]

func _valid(g: Dictionary) -> bool:
	# ровно одна горка дня
	var day := []
	for id in g:
		if g[id] >= 90:
			day.append(id)
	if day.size() != 1:
		return false
	# в каждой зоне есть >=60 и <=50
	for z in Slides.ZONES:
		var zs := []
		for id in Slides.in_zone(z):
			zs.append(g[id])
		if not (zs.max() >= 60 and zs.min() <= 50):
			return false
	# горки <50 минимум в двух зонах
	var low_zones := {}
	for id in g:
		if g[id] < 50:
			low_zones[Slides.SLIDES[id]["zone"]] = true
	if low_zones.size() < 2:
		return false
	# сумма зоны не дальше 25% от средней
	var sums := {}
	for z in Slides.ZONES:
		var s := 0
		for id in Slides.in_zone(z):
			s += g[id]
		sums[z] = s
	var avg: float = (sums["klyk"] + sums["delta"] + sums["zero"]) / 3.0
	for z in Slides.ZONES:
		if abs(sums[z] - avg) > 0.25 * avg:
			return false
	return true

# Пиковая очередь горки (сек) при текущей фазе
func peak_queue(slide_id: String) -> float:
	var base := 60.0 * float(gul.get(slide_id, 50)) / 50.0
	return base * Clock.queue_phase_multiplier()
