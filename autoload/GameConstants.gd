extends Node
## Автолоад: все замороженные константы (DESIGN FROZEN v1.0).
## Единый источник правды. Мировое время × run_scale; реакционное — реальные секунды.

# --- Время ---
const RUN_LENGTH_BASE: float = 1800.0   # 30 мин = 100%
var run_length: float = RUN_LENGTH_BASE  # меняется пресетом лобби (20/30/40)
var run_scale: float:
	get: return run_length / RUN_LENGTH_BASE

const PLANNING_WINDOW: float = 20.0      # реальные сек, часы на паузе

# Расписание (доли дня)
const SHOW_SLOTS: Array[float] = [0.16, 0.42, 0.67]
const PARADE: float = 0.33
const MAINT: float = 0.50
const DESK_CLOSE: float = 0.75
const BALLAD: float = 0.90

# Фазы (границы по доле дня)
const PHASE_MORNING_END: float = 0.25
const PHASE_NOON_END: float = 0.58
const PHASE_EVENING_END: float = 0.90

# --- Вес ---
const WEIGHT_START: float = 80.0
const WEIGHT_MIN: float = 70.0
const WEIGHT_MAX: float = 100.0          # потолок набора
const WEIGHT_LOCK: float = 91.0          # >= → не пускают на экстрим (тост)
const SPEED_AT_70: float = 0.85
const SPEED_AT_90: float = 1.15
const SNACK_KG: float = 1.0
const MEAL_KG: float = 2.0
const TOILET_KG: float = -3.0
const TOILET_COOLDOWN_FRAC: float = 0.25 # туалет раз в 3 ч (3/12 дня)
const SPLASH_HEAVY_KG: float = 85.0      # с этого веса всплеск «двойной»
const SPLASH_HEAVY_DELAY: float = 0.12   # задержка второго звука брызг (тяжёлый игрок)

# --- Сжигание калорий (бег/прыжки > ходьба/плавание) ---
const CAL_PER_KG: float = 100.0          # калорий на −1 кг
const CAL_WALK: float = 1.0              # в секунду при ходьбе
const CAL_RUN: float = 3.0              # в секунду при беге
const CAL_SWIM: float = 0.8             # в секунду при плавании
const CAL_JUMP: float = 4.0             # за прыжок

# --- Тошнота/укачивание (зелёная HP-шкала) ---
const DIZZY_MAX: int = 10              # полная шкала → кататься нельзя, надо отдохнуть
const NAUSEA_RIDE_BASE: int = 1        # гарантированный прирост за любой заезд (+ тег dizzy горки)
const NAUSEA_WARN: int = 7             # с этого уровня предупреждаем игрока

# --- Экономика ---
const COINS_START: int = 10
const THRIFT_DIV: int = 2
const THRIFT_CAP: int = 5

# --- Предметы (магазин) ---
const PILL_COST: int = 3        # таблетка от тошноты (тошнота → 0)
const GUN_COST: int = 8         # пистолет-отталкиватель (разово)
const GUN_RANGE: float = 9.0    # дальность толчка
const GUN_CONE: float = 0.45    # ширина конуса (dot-порог)
const GUN_FORCE: float = 14.0   # сила отталкивания
const GUN_CD: float = 0.8       # перезарядка

# --- Квесты ---
const D_TARGET: float = 14.0
const D_TOL: float = 2.0
const TIME_BAND: Array[float] = [0.30, 0.50]
const MAIN_PAYOUT: int = 20
const PERSONAL_PTS: int = 5
const COMMON_PTS: int = 4
const GEN_MAX_TRY: int = 60

# --- Очки (динамика) ---
const ZONE_FIRST: int = 5
const RACE_WIN: int = 3
const RACE_WIN_CAP: int = 3
const SIDE_OK: int = 5
const SIDE_FAIL: int = -3
const NO_LONG_QUEUE_BONUS: int = 2
const SHAME: int = -2
const MISS_BALLAD: int = -3
const SHOW_PTS: int = 4                 # очки за посещение шоу в театре

# --- Очередь / охрана ---
const HOOLIGAN_BAN_AFTER: int = 2       # после стольких нарушений — бан прыжков без очереди
const QUEUES_TO_RESTORE_RUN: int = 5    # сколько честных очередей отстоять, чтобы вернуть бег
const GUARD_FOLLOW_DIST: float = 4.0    # на какой дистанции охранник держится

# --- Театр ---
const SHOW_OPEN_BEFORE_FRAC: float = 1.0 / 12.0   # открыт за 1 игровой час до шоу
const SHOW_DURATION_FRAC: float = 0.5 / 12.0      # шоу идёт ~30 игровых минут

# --- Сложный режим ---
const HARD_MAIN_FAIL: int = -10
const HARD_PERSONAL_FAIL: int = -5
const HARD_COMMON_FAIL: int = -4

# --- Метки/пинги ---
const MARKER_COLORS: int = 4
const MARKER_DWELL: float = 5.0
const PING_LIFE: float = 12.0
const PING_CD: float = 3.0

# Перевод доли дня в реальные секунды текущего забега
func frac_to_seconds(frac: float) -> float:
	return frac * run_length
