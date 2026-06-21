# Модели

Сюда кладём 3D-модели из Blender. Формат: **.glb** (рекомендуется; всё в одном файле),
либо `.gltf`. `.obj` тоже импортируется.

## Как добавить модель, чтобы она заработала
1. В Blender: масштаб 1 unit = 1 метр, `Ctrl+A → Apply Scale`, origin в основание.
   UV-развёртка, материалы/текстуры. `File → Export → glTF 2.0 (.glb)` → сюда.
2. Godot импортирует `.glb` как сцену автоматически.
3. Использование (два пути):
   - **Вручную (красиво):** перетащи `.glb` из FileSystem в `world/ParkGreybox.tscn`
     (заведи узел `Decor`/`Buildings`), двигай гизмо.
   - **Кодом (системно):** инстансируй из `world/ParkBuilder.gd` рядом с остальными POI.

## Обязательно (иначе сломается геймплей)
- **Коллизия:** в Blender назови меш-коллайдер с суффиксом `-col` (Godot сделает
  StaticBody автоматически) ИЛИ добавь в Godot `StaticBody3D` + `CollisionShape3D`.
- **Навмеш:** проходимые поверхности и препятствия добавляй в группу **`navsource`**
  (иначе NPC не учтут; навмеш печётся на `run_started`).
- Текстуры храни рядом с `.glb` или встрой в файл при экспорте.

## Персонажи (игрок и NPC)

Тело персонажа — это компонент [`player/CharacterRig.gd`](../../player/CharacterRig.gd):
переиспользуемая «заготовка-силуэт» из примитивов с готовыми позами (ожидание,
ходьба, бег, прыжок, спуск с горки, плавание) и видом от первого лица.

- Создаётся одной строкой: `CharacterRig.make(рост, цвет_кожи, цвет_одежды, от_первого_лица)`.
- Игрок: [`player/PlayerController.gd`](../../player/PlayerController.gd) → `_build_visual()`.
- NPC: [`systems/npc/Visitor.gd`](../../systems/npc/Visitor.gd),
  [`systems/npc/NPCAgent.gd`](../../systems/npc/NPCAgent.gd) → `_drive_rig()`.

**Чтобы вставить модель из Blender:** импортируй `.glb` (скелет + меши + анимации),
удали узел `Placeholder` внутри рига и вставь свою модель; перенаправь
`head_anchor()`/`hand_anchor_r()`/`tray_anchor()` на свои кости (BoneAttachment3D).
Пропорции силуэта правятся в инспекторе (`total_height`, `build`, `head_scale`) —
по ним и лепи модель. Один риг → одинаково для игрока и всех NPC.

## Тун-стиль на модель

Стиль накладывается материалом из фабрики `Look` (см. [../../ART_STYLE.md](../../ART_STYLE.md)):
- просто цветом: `mesh.material_override = Look.mat(Look.WOOD)`;
- с текстурой модели: в импорте `.glb` сделай материал «extractable», поставь на
  surface `ShaderMaterial` (`res://assets/shaders/toon.gdshader`) и в параметр
  `tex` подставь текстуру.

Подробно про шейдеры: [../shaders/README.md](../shaders/README.md).
