extends Node
## Прогон генератора главного квеста N раз. Проверяет, что проверенное ядро
## (Hype + QuestGenerator) живо в Godot: каждый забег даёт валидный бандл из 2–3
## атомов, ep близко к цели, доля дня в коридоре. Запуск: открыть
## tests/quest_gen_check.tscn и нажать F6 (Run Current Scene) — отчёт в консоли.

const RUNS := 200

func _ready() -> void:
	var ok := 0
	var too_small := 0
	var ep_sum := 0.0
	var t_sum := 0.0
	var ep_lo := 999.0
	var ep_hi := 0.0

	for i in RUNS:
		Hype.roll(i)                       # детерминированный сид -> воспроизводимо
		var bundle: Array = QuestGenerator.generate_main()
		if bundle.size() < 2:
			too_small += 1
			continue
		ok += 1
		var ep := 0.0
		var t := 0.0
		for a in bundle:
			ep += float(a["ep"])
			t += float(a["t"])
		ep_sum += ep
		t_sum += t
		ep_lo = min(ep_lo, ep)
		ep_hi = max(ep_hi, ep)

	print("=== QuestGenerator check: %d прогонов ===" % RUNS)
	print("  валидных бандлов (>=2 атома): %d" % ok)
	print("  слишком маленьких:            %d" % too_small)
	if ok > 0:
		print("  ep: средн %.2f  (цель %.1f ± %.1f), диапазон [%.1f .. %.1f]" \
			% [ep_sum / ok, GameConstants.D_TARGET, GameConstants.D_TOL, ep_lo, ep_hi])
		print("  доля дня (t/RUN_LENGTH_BASE): средн %.3f  (коридор %s)" \
			% [(t_sum / ok) / GameConstants.RUN_LENGTH_BASE, str(GameConstants.TIME_BAND)])
	print("=== done ===")
	get_tree().quit()
