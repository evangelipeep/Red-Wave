extends Node
## Справочник фуд-корта: 5 лавок, их блюда, цены, эффекты, цвета.
## Аналог data/slides.gd — статический словарь (позже можно вынести в .tres).
##
## Лавка: id, name, color (корпус + цвет пищалки-трекера), effect (id бафа из
##   PlayerBuffs), effect_min (длительность бафа в ИГРОВЫХ минутах; 0 = разовый/без таймера),
##   dishes[] {id, name, price (монеты), kg (+вес), dizzy (Δголовы, минус = снимает)}.

const STALL_ORDER: Array[String] = ["fastfood", "mex", "asia", "veg", "coffee"]

const STALLS: Dictionary = {
	"fastfood": {
		"name": "Фастфуд",
		"color": Color(0.88, 0.24, 0.20),    # красный
		"effect": "heavy", "effect_min": 30.0,   # тяжесть: скорость ×0.8
		"dishes": [
			{"id": "fries",      "name": "Картошка фри",      "price": 2, "kg": 1.5, "dizzy": -2},
			{"id": "cheese",     "name": "Чизбургер",         "price": 2, "kg": 2.0, "dizzy": -3},
			{"id": "double",     "name": "Двойной чизбургер", "price": 4, "kg": 3.0, "dizzy": -4},
			{"id": "soda",       "name": "Газировка",         "price": 2, "kg": 0.5, "dizzy": -1},
		],
	},
	"mex": {
		"name": "Мексика",
		"color": Color(0.30, 0.70, 0.35),    # зелёный
		"effect": "spicy", "effect_min": 0.0,    # остро: следующий туалет без кулдауна
		"dishes": [
			{"id": "burrito",    "name": "Буррито",        "price": 2, "kg": 1.5, "dizzy": -2},
			{"id": "taco",       "name": "Тако",           "price": 1, "kg": 1.0, "dizzy": -1},
			{"id": "tomato_jc",  "name": "Томатный сок",   "price": 1, "kg": 0.3, "dizzy": -1},
		],
	},
	"asia": {
		"name": "Азия",
		"color": Color(0.92, 0.80, 0.20),    # жёлтый
		"effect": "hotsoup", "effect_min": 30.0, # горячий суп: сжигание калорий ×1.5
		"dishes": [
			{"id": "tom_yam",    "name": "Том ям",  "price": 5, "kg": 1.0, "dizzy": -3},
			{"id": "ramen",      "name": "Рамен",   "price": 4, "kg": 1.5, "dizzy": -3},
		],
	},
	"veg": {
		"name": "Овощи",
		"color": Color(0.30, 0.55, 0.92),    # синий
		"effect": "light", "effect_min": 0.0,    # лёгкая еда: почти без веса
		"dishes": [
			{"id": "salad",      "name": "Салат томат-огурец", "price": 1, "kg": 0.25, "dizzy": -1},
			{"id": "tomato",     "name": "Помидор",            "price": 1, "kg": 0.25, "dizzy": -1},
		],
	},
	"coffee": {
		"name": "Кофейня",
		"color": Color(0.58, 0.36, 0.76),    # фиолетовый
		"effect": "caffeine", "effect_min": 10.0, # кофеин: скорость ×2
		"dishes": [
			{"id": "bubble_tea", "name": "Бабл-ти с кофе", "price": 5, "kg": 0.5, "dizzy": 0},
			{"id": "bumble",     "name": "Бамбл-кофе",     "price": 5, "kg": 0.3, "dizzy": 0},
			{"id": "esp_tonic",  "name": "Эспрессо-тоник", "price": 5, "kg": 0.2, "dizzy": 0},
			{"id": "matcha",     "name": "Мачча-латте",    "price": 4, "kg": 0.4, "dizzy": 0},
		],
	},
}

func ids() -> Array:
	return STALL_ORDER

func stall(stall_id: String) -> Dictionary:
	return STALLS.get(stall_id, {})

func stall_name(stall_id: String) -> String:
	return str(STALLS.get(stall_id, {}).get("name", stall_id))

func stall_color(stall_id: String) -> Color:
	return STALLS.get(stall_id, {}).get("color", Color.WHITE)

func dishes(stall_id: String) -> Array:
	return STALLS.get(stall_id, {}).get("dishes", [])

# Описание блюда по id лавки и id блюда (или пустой словарь).
func dish(stall_id: String, dish_id: String) -> Dictionary:
	for d in dishes(stall_id):
		if d["id"] == dish_id:
			return d
	return {}
