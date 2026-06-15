extends Node
## Автолоад: глобальная шина сигналов. Системы не зовут друг друга напрямую,
## а издают/слушают здесь. Критично для фазы 3 (сеть): сервер сможет
## перехватывать те же сигналы без переписывания систем.

# Сигналы издаются из других классов (Clock, системы), поэтому Godot считает их
# «неиспользуемыми внутри класса» — для шины событий это норма, глушим предупреждение.
@warning_ignore_start("unused_signal")
signal run_started()
signal run_planning_started()
signal phase_changed(phase: String)
signal scheduled_event(event: String)                       # "show_1", "parade", "maintenance", "ballad"
signal slide_completed(player_id: int, slide_id: String)    # «достиг бассейна» (баг #21)
signal weight_changed(player_id: int, kg: float)
signal dizziness_changed(player_id: int, level: int)
signal zone_closed(player_id: int, zone: String)            # первопроходец (server-auth позже)
signal quest_progress(player_id: int, quest_id: String, done: bool)
signal ping_made(player_id: int, world_pos: Vector3, context: String)
signal toast(message: String)                               # всплывающее уведомление в HUD
@warning_ignore_restore("unused_signal")
