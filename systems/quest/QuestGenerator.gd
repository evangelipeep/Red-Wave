extends Node
## Генератор главного квеста: бандл из 2–3 атомов, баланс по ДВУМ осям (ep + время),
## COMPATIBLE() против провальных сочетаний, fallback на 10 провалидированных бандлов.
## Порт проверенной симуляции (σ_времени ≈ 5.4 п.п., 0 провалов на 300 забегов).

# Атом: {name, ep, t, fixed, coin, axis, supply}
# t — оценка времени в секундах при run_length=1800 (доля дня = t/1800).

func _ride_time(slide_id: String) -> float:
	# дорога + половина пиковой очереди + спуск
	return 40.0 + Hype.peak_queue(slide_id) * 0.5 + 25.0

func _build_atoms() -> Array:
	var A: Array = []
	var extreme := Slides.extreme_ids()
	var calm := Slides.calm_ids()
	var low := []
	for id in Hype.gul:
		if Hype.gul[id] < 50:
			low.append(id)

	# RIDE_EXTREME(n)
	for n in [1, 2]:
		if extreme.size() >= n:
			A.append({"name":"Экстрим×%d"%n, "ep":3.0*n, "t":_sum_smallest(extreme, n),
				"fixed":false, "coin":0, "axis":"extreme", "n":n})
	# RIDE_SENSATION(s,n)
	var senses := ["padenie","mrak","skolzhenie","nevesomost","pogruzhenie","kruzhenie"]
	for s in senses:
		var lst := Slides.with_sensation(s)
		for n in [2, 3]:
			if lst.size() >= n:
				var zones := {}
				for id in lst: zones[Slides.SLIDES[id]["zone"]] = true
				var bonus := 1.0 if zones.size() >= 3 else 0.0
				A.append({"name":"Ощущение %s×%d"%[s,n], "ep":1.5*n+bonus, "t":_sum_smallest(lst,n),
					"fixed":false, "coin":0, "axis":"sens", "n":n, "sensation":s})
	# RIDE_TEMP(temp,n)
	for tname in ["ice", "warm"]:
		var lst := Slides.with_temp(tname)
		for n in [2, 3]:
			if lst.size() >= n:
				A.append({"name":"Темп %s×%d"%[tname,n], "ep":1.5*n, "t":_sum_smallest(lst,n),
					"fixed":false, "coin":0, "axis":"temp", "n":n, "temp":tname})
	# RIDE_GUL_BELOW(n)
	for n in [2, 3]:
		if low.size() >= n:
			A.append({"name":"Гул<50×%d"%n, "ep":1.3*n, "t":_sum_smallest(low,n),
				"fixed":false, "coin":0, "axis":"gul", "n":n})
	# ONE_PER_ZONE
	var tz := 0.0
	for z in Slides.ZONES:
		var best := 1e9
		for id in Slides.in_zone(z): best = min(best, _ride_time(id))
		tz += best
	A.append({"name":"По одной в каждой зоне", "ep":4.0, "t":tz, "fixed":false, "coin":0, "axis":"perzone"})
	# CLOSE_ZONE(z)
	for z in Slides.ZONES:
		var t := 0.0
		for id in Slides.in_zone(z): t += _ride_time(id)
		A.append({"name":"Закрой зону %s"%z, "ep":7.0, "t":t, "fixed":false, "coin":0, "axis":"closezone", "zone":z})
	# DIFFERENT_SENSATIONS(k)
	for k in [3, 4]:
		A.append({"name":"%d разных ощущений"%k, "ep":1.5*k, "t":k*90.0, "fixed":false, "coin":0, "axis":"diffsens", "n":k})
	# RIDE_CALM(n)
	for n in [1, 2]:
		if calm.size() >= n:
			A.append({"name":"Спокойные×%d"%n, "ep":3.0*n, "t":n*100.0, "fixed":false, "coin":0, "axis":"calm", "n":n})
	# ATTEND_SHOWS(k)  (fixed_time)
	for k in [1, 2, 3]:
		A.append({"name":"Театры×%d"%k, "ep":3.0*k, "t":k*110.0, "fixed":true, "coin":0, "axis":"shows", "n":k})
	# PHOTO_BARD
	A.append({"name":"Фото с Бардом", "ep":3.0, "t":120.0, "fixed":false, "coin":0, "axis":"bard"})
	# FOOD_STALLS — поешь в 3 разных лавках фуд-корта
	A.append({"name":"Поешь в 3 разных лавках", "ep":3.0, "t":135.0, "fixed":false, "coin":3, "axis":"food"})
	# COLLECT_SOUVENIRS
	A.append({"name":"Сувенир из каждой лавки", "ep":4.0, "t":135.0, "fixed":false, "coin":5, "axis":"shop"})
	# WEIGHT_END_BELOW79 / EXTREME_AT
	A.append({"name":"Финиш ≤79 кг", "ep":4.0, "t":120.0, "fixed":false, "coin":0, "axis":"weightlow"})
	A.append({"name":"Экстрим на 88–90 кг", "ep":3.0, "t":_ride_time(extreme[0])+60.0, "fixed":false, "coin":2, "axis":"weighthi"})
	# DIZZY_MAX_THEN_CLEAR
	A.append({"name":"Голов.5→0 до 19:00", "ep":3.0, "t":150.0, "fixed":false, "coin":0, "axis":"dizzy"})
	# RACE_WIN(n)
	for n in [1, 2]:
		A.append({"name":"Победа в Рое×%d"%n, "ep":3.0*n, "t":n*90.0, "fixed":false, "coin":0, "axis":"race", "n":n})
	# QUEUE_SKIP(n)
	for n in [1, 2]:
		A.append({"name":"Без очереди×%d"%n, "ep":2.5*n, "t":n*30.0, "fixed":false, "coin":0, "axis":"skip", "n":n})
	# CAPILLYAR_LAPS(n)
	for n in [2, 3]:
		A.append({"name":"Круги по реке×%d"%n, "ep":2.0*n, "t":n*90.0, "fixed":false, "coin":0, "axis":"laps", "n":n})
	return A

func _sum_smallest(ids: Array, n: int) -> float:
	var times := []
	for id in ids: times.append(_ride_time(id))
	times.sort()
	var s := 0.0
	for i in range(min(n, times.size())): s += times[i]
	return s

func _compatible(atom: Dictionary, bundle: Array) -> bool:
	for b in bundle:
		if b["axis"] == atom["axis"]:
			return false                      # дедуп оси
	var fixed_cnt := (1 if atom["fixed"] else 0)
	var coins: float = atom["coin"]
	var tsum: float = atom["t"]
	for b in bundle:
		fixed_cnt += (1 if b["fixed"] else 0)
		coins += b["coin"]
		tsum += b["t"]
	if fixed_cnt > 1: return false             # макс 1 жёстко-временной
	if coins > 10: return false                # бюджет монет
	if tsum > 0.50 * GameConstants.RUN_LENGTH_BASE: return false  # верх коридора времени
	return true

## Главная функция: вернуть бандл (массив атомов) для главного квеста.
func generate_main() -> Array:
	var atoms := _build_atoms()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for _try in range(GameConstants.GEN_MAX_TRY):
		atoms.shuffle()
		var bundle: Array = []
		for a in atoms:
			var ep_sum := 0.0
			for b in bundle: ep_sum += b["ep"]
			if ep_sum >= GameConstants.D_TARGET or bundle.size() >= 3:
				break
			if _compatible(a, bundle):
				bundle.append(a)
		var ep := 0.0
		var t := 0.0
		for b in bundle:
			ep += b["ep"]; t += b["t"]
		var tfrac := t / GameConstants.RUN_LENGTH_BASE
		if abs(ep - GameConstants.D_TARGET) <= GameConstants.D_TOL \
			and bundle.size() >= 2 \
			and tfrac >= GameConstants.TIME_BAND[0] and tfrac <= GameConstants.TIME_BAND[1]:
			return bundle
	# fallback
	return _load_fallback()

func _load_fallback() -> Array:
	var f := FileAccess.open("res://data/fallback_bundles.json", FileAccess.READ)
	if f == null:
		return []
	var data: Array = JSON.parse_string(f.get_as_text())
	f.close()
	if data == null or data.is_empty():
		return []
	return data[randi() % data.size()]

## Личное доп-задание: один лёгкий, отслеживаемый атом (PERSONAL_PTS за выполнение).
func generate_personal() -> Array:
	var trackable := ["extreme", "sens", "temp", "gul", "calm", "diffsens", "food",
		"weightlow", "weighthi", "dizzy", "perzone"]
	var pool: Array = []
	for a in _build_atoms():
		if a.get("axis", "") in trackable and float(a.get("ep", 0.0)) <= 4.0:
			pool.append(a)
	if pool.is_empty():
		return []
	return [pool[randi() % pool.size()]]
