extends Node
## Автолоад: глобальная шина сигналов. Системы не зовут друг друга напрямую,
## а издают/слушают здесь. Критично для фазы 3 (сеть): сервер сможет
## перехватывать те же сигналы без переписывания систем.

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
