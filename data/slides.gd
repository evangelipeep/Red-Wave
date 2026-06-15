extends Node
## БД горк (15 шт.) с тегами. Можно вынести в .tres Resource позже; пока — словарь.
## Поля: zone, dizzy, type[], sensation, temp, extreme, calm

const SLIDES: Dictionary = {
	# --- Северный Клык ---
	"klyk":        {"zone":"klyk",  "dizzy":3, "type":["spusk","bashnya"],      "sensation":"padenie",     "temp":"neutral", "extreme":true,  "calm":false},
	"plashch":     {"zone":"klyk",  "dizzy":2, "type":["truba","temnota"],      "sensation":"mrak",        "temp":"ice",     "extreme":false, "calm":false},
	"krylo":       {"zone":"klyk",  "dizzy":2, "type":["zhelob"],               "sensation":"nevesomost",  "temp":"neutral", "extreme":false, "calm":false},
	"vitrazh":     {"zone":"klyk",  "dizzy":1, "type":["truba"],                "sensation":"pogruzhenie", "temp":"warm",    "extreme":false, "calm":false},
	"kolybelnaya": {"zone":"klyk",  "dizzy":0, "type":["lodki"],                "sensation":"skolzhenie",  "temp":"ice",     "extreme":false, "calm":true},
	# --- Дельта ---
	"zhalo":       {"zone":"delta", "dizzy":3, "type":["spusk","polet"],        "sensation":"nevesomost",  "temp":"warm",    "extreme":true,  "calm":false},
	"khobotok":    {"zone":"delta", "dizzy":2, "type":["truba","spiral"],       "sensation":"kruzhenie",   "temp":"neutral", "extreme":false, "calm":false},
	"top":         {"zone":"delta", "dizzy":2, "type":["spusk"],                "sensation":"pogruzhenie", "temp":"warm",    "extreme":false, "calm":false},
	"roy":         {"zone":"delta", "dizzy":1, "type":["gonka","gruppovaya"],   "sensation":"skolzhenie",  "temp":"neutral", "extreme":false, "calm":false},
	"mangry":      {"zone":"delta", "dizzy":0, "type":["lodki","temnota"],      "sensation":"mrak",        "temp":"warm",    "extreme":false, "calm":true},
	# --- Серый Пояс Зеро ---
	"vabank":      {"zone":"zero",  "dizzy":3, "type":["spusk","kapsula"],      "sensation":"padenie",     "temp":"neutral", "extreme":true,  "calm":false},
	"ruletka":     {"zone":"zero",  "dizzy":2, "type":["voronka","gruppovaya"], "sensation":"kruzhenie",   "temp":"neutral", "extreme":false, "calm":false},
	"dzhekpot":    {"zone":"zero",  "dizzy":2, "type":["truba","random"],       "sensation":"pogruzhenie", "temp":"neutral", "extreme":false, "calm":false},
	"razmen":      {"zone":"zero",  "dizzy":1, "type":["truba","random"],       "sensation":"skolzhenie",  "temp":"ice",     "extreme":false, "calm":false},
	"nol":         {"zone":"zero",  "dizzy":0, "type":["lodki","temnota"],      "sensation":"mrak",        "temp":"ice",     "extreme":false, "calm":true},
}

const ZONES: Array[String] = ["klyk", "delta", "zero"]

func ids() -> Array:
	return SLIDES.keys()

func in_zone(zone: String) -> Array:
	var r := []
	for id in SLIDES:
		if SLIDES[id]["zone"] == zone:
			r.append(id)
	return r

func with_sensation(s: String) -> Array:
	var r := []
	for id in SLIDES:
		if SLIDES[id]["sensation"] == s:
			r.append(id)
	return r

func with_temp(t: String) -> Array:
	var r := []
	for id in SLIDES:
		if SLIDES[id]["temp"] == t:
			r.append(id)
	return r

func extreme_ids() -> Array:
	var r := []
	for id in SLIDES:
		if SLIDES[id]["extreme"]:
			r.append(id)
	return r

func calm_ids() -> Array:
	var r := []
	for id in SLIDES:
		if SLIDES[id]["calm"]:
			r.append(id)
	return r
