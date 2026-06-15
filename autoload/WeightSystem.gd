extends Node
## Автолоад: вес игрока(ов). СТАБ фазы 1 — даёт рабочий API, но без реальной
## модели набора/сжигания. Полная версия пишется на неделе 2–3 (вес→скорость,
## лок экстрима, еда/туалет/бег). Сейчас возвращает безопасные значения,
## чтобы SlideRail и HUD могли к нему обращаться уже сейчас.

const KG_MIN := 60.0
const KG_MAX := 120.0

var kg: float = KG_MIN

func eat(_amount: float = 5.0) -> void:
	# TODO(неделя3): набор веса + сигнал weight_changed
	pass

func toilet() -> void:
	# TODO(неделя3): сброс веса
	pass

func add_run_distance(_meters: float) -> void:
	# TODO(неделя3): бег сжигает вес
	pass

# Множитель скорости спуска от веса (тяжелее = быстрее). СТАБ: всегда 1.0.
func speed_factor() -> float:
	return 1.0

# Можно ли на экстрим-горку (лок по весу). СТАБ: всегда да.
func can_ride_extreme() -> bool:
	return true
