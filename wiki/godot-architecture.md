# Архитектура Godot-проекта

Godot 4.x, GDScript. Системы развязаны через сигналы EventBus — это критично для
коопа ([[coop-networking]]): сервер перехватывает те же сигналы. Авторитет сервера
на всём важном.

## Содержание

**Автолоады (порядок важен):**
1. `GameConstants` — чистые `const` (см. [[constant-reference]]), ни от кого не зависит.
2. `EventBus` — только сигналы, развязка издатель/подписчик.
3. `Clock` — двигает `day_fraction` 0→1, мировое (×run_scale) и реакционное время
   ([[day-cycle-and-time]]).
4. `Hype` — бросок [[hype-gul|Гула]] на старте, `gul[slide_id]`, `day_slide`.
5. `WeightSystem` — [[weight-system|вес]]: `eat()`, `toilet()`, `speed_factor()`,
   `can_ride_extreme()`.
6. `Net` — стаб в фазе 1, настоящий авторитет в фазе 3.

**Ключевые сигналы EventBus:** `run_started`, `run_planning_started`,
`phase_changed`, `scheduled_event`, `slide_completed(player_id, slide_id)`,
`weight_changed`, `dizziness_changed`, `zone_closed`, `quest_progress`,
`ping_made(player_id, world_pos, context)`.

**Дерево папок:** `autoload/`, `data/` (slides.gd — 15 горк, fallback_bundles.json),
`systems/` (quest/, slide/, zone/, poi/, npc/), `player/`, `world/` (ParkGreybox,
Lighting, ParkBuilder), `ui/` (HUD, MapOverlay, Minimap), `tests/`.

**Реализация горок:** `SlideRail` — труба `CSGPolygon3D` вдоль `Path3D`; скорость =
`WeightSystem.speed_factor()`. Горка сама копает яму-бассейн в полу (группа `ground`).

**NavMesh:** `NavigationRegion3D`, бейк по группе `navsource` на старте дня (бейк
отложен на 2 кадра — коллизия CSG считается не в `_ready`). NPC — `NavigationAgent3D`
([[npc-and-crowd]]).

**Игрок/риг:** модель персонажа грузится в слот под Blender-риг
(`CharacterRig.model_scene`) с фолбэком; ячейка слота переиспользуемая. Исправлен
чёрный экран в виде от первого лица ([[first-person-camera]]).

**Валидация без редактора (headless):**
`godot --headless --editor --quit --path <проект>` — парсинг скриптов;
`--headless --fixed-fps 60 --quit-after N <scene>` — рантайм (день авто-стартует
через 20с планирования). Новый `class_name` сперва требует `--editor`.

## Связано с

- [[constant-reference]] — GameConstants
- [[coop-networking]] — сервер перехватывает EventBus
- [[day-cycle-and-time]] — Clock
- [[npc-and-crowd]] — NavMesh
- [[art-style]] — шейдеры, фабрика Look
- [[development-roadmap]] — что реально в фазе 1 vs стабы

## Источник

- [PHASE1_PLAN.md](../PHASE1_PLAN.md) §1–3 структура и сигналы
- [GDD_FULL_v0.6.md](../GDD_FULL_v0.6.md) §14 Техрамки
