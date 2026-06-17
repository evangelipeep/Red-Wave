extends Node
## Кооп-синхронизация (первый слой): рассылает позицию локального игрока другим
## пирами (rpc ~20 Гц) и показывает их аватары. Аддитивно — оффлайн ничего не делает,
## одиночная игра не меняется. Синхрон состояния (Гул/квесты) — следующий шаг (server-auth).

const SEND_HZ := 20.0

var _avatars: Dictionary = {}   # peer_id -> RemoteAvatar
var _send_accum: float = 0.0
var _clock_accum: float = 0.0

func _ready() -> void:
	Net.peer_left.connect(_on_peer_left)
	EventBus.run_started.connect(_on_run_started)

func _process(delta: float) -> void:
	if not Net.is_online():
		return
	_send_accum += delta
	if _send_accum >= 1.0 / SEND_HZ:
		_send_accum = 0.0
		var p := get_tree().get_first_node_in_group("player") as Node3D
		if p != null:
			rpc("_recv_pos", p.global_position, p.global_rotation.y)
	# Хост держит у всех одно время дня (анти-дрейф).
	if Net.is_server() and Clock.running:
		_clock_accum += delta
		if _clock_accum >= 1.0:
			_clock_accum = 0.0
			rpc("_sync_clock", Clock.day_fraction)

# --- Синхрон дня: хост → клиенты (один Гул, один квест, одно время). ---
func _on_run_started() -> void:
	if Net.is_online() and Net.is_server():
		rpc("_sync_session", Hype.gul, Hype.day_slide, RunState.main_quest, GameConstants.run_length)

@rpc("authority", "reliable", "call_remote")
func _sync_session(gul: Dictionary, day_slide: String, mq: Array, rl: float) -> void:
	Hype.gul = gul
	Hype.day_slide = day_slide
	RunState.main_quest = mq
	GameConstants.run_length = rl
	Clock.start_run()
	EventBus.run_started.emit()
	print("[Coop] получен день хоста: горка дня = %s" % day_slide)

@rpc("authority", "unreliable", "call_remote")
func _sync_clock(df: float) -> void:
	Clock.day_fraction = df

@rpc("any_peer", "unreliable", "call_remote")
func _recv_pos(pos: Vector3, yaw: float) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not _avatars.has(id):
		var av := RemoteAvatar.new()
		add_child(av)
		av.global_position = pos
		_avatars[id] = av
		print("[Coop] аватар игрока %d создан" % id)
	(_avatars[id] as RemoteAvatar).set_target(pos, yaw)

func _on_peer_left(id: int) -> void:
	if _avatars.has(id):
		(_avatars[id] as Node).queue_free()
		_avatars.erase(id)
