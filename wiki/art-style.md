# Визуальный стиль (тун-шейдинг)

Стиль — плоские чистые цвета + ступенчатый свет + чёрный контур + мягкий свет/туман,
как в Zelda: Wind Waker. Форма делается в Blender, «соус» (тун) — в Godot через
фабрику материалов `Look`.

## Содержание

**Разделение труда:** форма (здания/декор) → Blender `.glb`; стиль (тун, контур,
свет) → Godot шейдеры + Environment; расстановка → редактор Godot; геймплей → код.

**Готовая база:**
- `assets/shaders/`: `toon.gdshader` (основной), `toon_alpha.gdshader` (стекло/вода),
  `toon_light.gdshaderinc` (общая формула света), `outline.gdshader` (контур
  «вывернутый корпус»).
- `autoload/Look.gd` — **фабрика материалов + палитра** (autoload, зовётся как `Look`).
  Все старые помощники материалов (`ParkBuilder`, `HeartBuilding`, `SlideRail`,
  POI-скрипты) переведены на фабрику → весь парк уже тун-стайл.
- `WorldEnvironment` в `ParkGreybox.tscn` настроен под тун; свет дня (`Lighting.gd`)
  крутит цвет/энергию по [[day-cycle-and-time|времени суток]].

**API фабрики:**
- `Look.mat(color, outline := true, transparent := false) -> ShaderMaterial`
- `Look.emissive(color, energy := 2.0, outline := false) -> ShaderMaterial`

**Крутилки:** `Look.BANDS` (резкость света), `Look.OUTLINE_WIDTH/COLOR`, палитра
`SKY/WATER/WAVE/...`, нода `WorldEnvironment`. Совет: 8–12 базовых цветов — палитра
важнее детализации.

**Добавить здание:** Blender (1 unit = 1 м, low-poly) → Apply Scale → Smart UV →
Base Color → экспорт `.glb` в `assets/models/buildings/` → в Godot навесить
`Look.mat(...)`; коллайдер суффиксом `-col` или `StaticBody3D`.

**Расстановка:** декор — сценами в редакторе (узел `Decor`); системное — кодом
(`ParkBuilder.gd`). Пол/препятствия для NPC — в группу `navsource` ([[godot-architecture]]).
Горки — путь рисуется через `Path3D` (см. [[park-map]]).

## Связано с

- [[godot-architecture]] — где живут шейдеры и autoload
- [[park-map]] — горки рисуются по `Path3D`
- [[day-cycle-and-time]] — свет дня
- [[development-roadmap]] — арт = фаза 6

## Источник

- [ART_STYLE.md](../ART_STYLE.md) — полный гайд по стилю
- assets: [shaders/README.md](../assets/shaders/README.md),
  [models/README.md](../assets/models/README.md),
  [audio/README.md](../assets/audio/README.md)
