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
			{"id": "fries",  "name": "Картошка фри",      "price": 2, "kg": 1.5, "dizzy": -2, "icon": "res://assets/ui/french_fries.png",
				"desc": "Золотистые соломки до хруста. Кетчуп цвета свежей добычи — макай не стесняясь."},
			{"id": "cheese", "name": "Чизбургер",         "price": 2, "kg": 2.0, "dizzy": -3, "icon": "res://assets/ui/burger.png",
				"desc": "Сочная котлета и плавленый сыр. Кусай во всю клыкастую пасть."},
			{"id": "double", "name": "Двойной чизбургер", "price": 4, "kg": 3.0, "dizzy": -4, "icon": "res://assets/ui/big_burger.png",
				"desc": "Двойная котлета для тех, кто охотился всю ночь. Тяжесть в брюхе прилагается."},
			{"id": "soda",   "name": "Газировка",         "price": 2, "kg": 0.5, "dizzy": -1, "icon": "res://assets/ui/cola.png",
				"desc": "Шипучие пузырьки, красные как закат над парком. Утоляет жажду (не ту самую)."},
		],
	},
	"mex": {
		"name": "Мексика",
		"color": Color(0.30, 0.70, 0.35),    # зелёный
		"effect": "spicy", "effect_min": 0.0,    # остро: следующий туалет без кулдауна
		"dishes": [
			{"id": "burrito",   "name": "Буррито",      "price": 2, "kg": 1.5, "dizzy": -2, "icon": "res://assets/ui/burrito.png",
				"desc": "Остро завёрнутая добыча. Жжёт так, что в туалет — немедленно."},
			{"id": "taco",      "name": "Тако",         "price": 1, "kg": 1.0, "dizzy": -1, "icon": "res://assets/ui/tako.png",
				"desc": "Хрустящая лодочка со специями. Маленький укус — большой пожар."},
			{"id": "tomato_jc", "name": "Томатный сок", "price": 1, "kg": 0.3, "dizzy": -1, "icon": "res://assets/ui/tomato_jusie.png",
				"desc": "Густой, красный, солёный. Почти как настоящий… почти."},
		],
	},
	"asia": {
		"name": "Азия",
		"color": Color(0.92, 0.80, 0.20),    # жёлтый
		"effect": "hotsoup", "effect_min": 30.0, # горячий суп: сжигание калорий ×1.5
		"dishes": [
			{"id": "tom_yam", "name": "Том ям", "price": 5, "kg": 1.0, "dizzy": -3, "icon": "res://assets/ui/tom_yam.png",
				"desc": "Острый горячий суп — кровь закипает, тело потеет, метаболизм визжит."},
			{"id": "ramen",   "name": "Рамен",  "price": 4, "kg": 1.5, "dizzy": -3, "icon": "res://assets/ui/ramen.png",
				"desc": "Наваристый бульон и лапша. Греет изнутри лучше тёплой шеи жертвы."},
		],
	},
	"veg": {
		"name": "Овощи",
		"color": Color(0.30, 0.55, 0.92),    # синий
		"effect": "light", "effect_min": 0.0,    # лёгкая еда: почти без веса
		"dishes": [
			{"id": "salad",  "name": "Салат томат-огурец", "price": 1, "kg": 0.25, "dizzy": -1, "icon": "res://assets/ui/salat.png",
				"desc": "Свежесть для следящих за фигурой кровопийц. Почти без веса, совсем без вины."},
			{"id": "tomato", "name": "Помидор",            "price": 1, "kg": 0.25, "dizzy": -1, "icon": "res://assets/ui/tomato.png",
				"desc": "Просто помидор. Вампир тоже иногда хочет чего-то невинного."},
		],
	},
	"coffee": {
		"name": "Кофейня",
		"color": Color(0.58, 0.36, 0.76),    # фиолетовый
		"effect": "caffeine", "effect_min": 10.0, # кофеин: скорость ×2
		"dishes": [
			{"id": "bubble_tea", "name": "Бабл-ти с кофе", "price": 5, "kg": 0.5, "dizzy": 0, "icon": "res://assets/ui/buble_tea.png",
				"desc": "Тапиока, кофе и дерзость. Пузырьки бодрят сильнее укуса."},
			{"id": "bumble",     "name": "Бамбл-кофе",     "price": 5, "kg": 0.3, "dizzy": 0, "icon": "res://assets/ui/coffe.png",
				"desc": "Апельсин и эспрессо — жужжишь, как комар на рассвете."},
			{"id": "esp_tonic",  "name": "Эспрессо-тоник", "price": 5, "kg": 0.2, "dizzy": 0, "icon": "res://assets/ui/coffe.png",
				"desc": "Горький эспрессо в игристом тонике. За спиной будто крылья (фигурально)."},
			{"id": "matcha",     "name": "Мачча-латте",    "price": 4, "kg": 0.4, "dizzy": 0, "icon": "res://assets/ui/coffe.png",
				"desc": "Зелёная, как зависть дневных людей. Мягкий кофеиновый разгон."},
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

# Картинка блюда (Texture2D) из его поля "icon" или null, если иконки нет/файл отсутствует.
func dish_icon(d: Dictionary) -> Texture2D:
	var p := str(d.get("icon", ""))
	if p != "" and ResourceLoader.exists(p):
		return load(p)
	return null

# Описание блюда по id лавки и id блюда (или пустой словарь).
func dish(stall_id: String, dish_id: String) -> Dictionary:
	for d in dishes(stall_id):
		if d["id"] == dish_id:
			return d
	return {}

# Человеко-читаемый баф/дебаф лавки (эффект общий для всех её блюд).
func effect_label(stall_id: String) -> String:
	var st: Dictionary = STALLS.get(stall_id, {})
	var mins := int(st.get("effect_min", 0.0))
	match str(st.get("effect", "")):
		"caffeine": return "☕ Кофеин: скорость ×2 на %d мин" % mins
		"heavy":    return "🍔 Тяжесть: пешком медленнее на %d мин" % mins
		"hotsoup":  return "🔥 Жар: сжигание калорий ×1.5 на %d мин" % mins
		"spicy":    return "🌶 Остро: следующий туалет без кулдауна"
		"light":    return "🥗 Лёгкое: почти без набора веса"
		_: return ""

func effect_is_debuff(stall_id: String) -> bool:
	return str(STALLS.get(stall_id, {}).get("effect", "")) == "heavy"

# Короткая строка статов блюда: вес и тошнота.
func dish_stats(d: Dictionary) -> String:
	var s := "Вес +%.2g кг" % float(d.get("kg", 0.0))
	var dz := int(d.get("dizzy", 0))
	if dz != 0:
		s += " · Тошнота %+d" % dz
	return s
