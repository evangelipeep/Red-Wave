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
const WEIGHT_MAX: float = 95.0
const WEIGHT_LOCK: float = 91.0          # >= → нет экстрима
const SPEED_AT_70: float = 0.85
const SPEED_AT_90: float = 1.15
const SNACK_KG: float = 1.0
const MEAL_KG: float = 2.0
const TOILET_KG: float = -3.0
const RUN_M_PER_KG: float = 400.0

# --- Головокружение ---
const DIZZY_MAX: int = 5

# --- Экономика ---
const COINS_START: int = 10
const THRIFT_DIV: int = 2
const THRIFT_CAP: int = 5

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
