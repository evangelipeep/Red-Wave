# Замороженные константы

Единый источник числовых констант (`GameConstants.gd`). Заморожены в DESIGN_FROZEN
v1.0 — менять только осознанным «design change». Все «мировые» длительности ×
`run_scale`; QTE/буферы/`PLANNING_WINDOW`/`PING_*` — реальные секунды.

## Содержание

```gdscript
RUN_LENGTH_BASE = 1800.0      # сек = 30 мин = 100%
WEIGHT_START = 80.0; WEIGHT_MIN = 70.0; WEIGHT_MAX = 95.0
WEIGHT_LOCK = 91.0            # ≥ → нет экстрима
SPEED_AT_70 = 0.85; SPEED_AT_90 = 1.15   # линейно, клам выше 90
DIZZY_MAX = 5
COINS_START = 10
D_TARGET = 14; D_TOL = 2; TIME_BAND = [0.30, 0.50]
MAIN_PAYOUT = 20; PERSONAL = 5; COMMON = 4
ZONE_FIRST = 5; RACE_WIN = 3; RACE_WIN_CAP = 3
SIDE_OK = 5; SIDE_FAIL = -3
THRIFT_DIV = 2; THRIFT_CAP = 5
NO_LONG_QUEUE_BONUS = 2; SHAME = -2; MISS_BALLAD = -3
HARD_MAIN_FAIL = -10; HARD_PERSONAL_FAIL = -5; HARD_COMMON_FAIL = -4
SHOW_SLOTS = [0.16, 0.42, 0.67]; PARADE = 0.33; MAINT = 0.50; DESK_CLOSE = 0.75; BALLAD = 0.90
PLANNING_WINDOW = 20.0        # реальные сек, часы на паузе
PING_KEY = "middle_click"; PING_LIFE = 12.0; PING_CD = 3.0
MARKER_COLORS = 4; MARKER_DWELL = 5.0
```

> Примечание: в реализации (v1.16) шоу сведены к `SHOW_SLOTS = [0.45, 0.90]`,
> отладочная длина дня `debug_run_length = 1200` (20 мин). См. [[development-roadmap]].

## Связано с

- [[weight-system]] — `WEIGHT_*`, `SPEED_*`
- [[quest-system]] — `D_TARGET`, `TIME_BAND`, `MAIN_PAYOUT`
- [[scoring]] — `ZONE_FIRST`, `RACE_WIN`, `THRIFT_*`, `SHAME`
- [[difficulty-presets]] — `HARD_*_FAIL`
- [[markers-and-pings]] — `PING_*`, `MARKER_*`
- [[day-cycle-and-time]] — `RUN_LENGTH_BASE`, `SHOW_SLOTS`, `PLANNING_WINDOW`
- [[godot-architecture]] — `GameConstants` автолоад

## Источник

- [DESIGN_FROZEN_v1.0.md](../DESIGN_FROZEN_v1.0.md) — Замороженные константы
