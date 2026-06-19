extends Node
## Кооп-синхронизация. Рассылает позицию локального игрока (rpc ~20 Гц) и показывает
## аватары других; синхронизирует день от хоста (Гул/квест/часы); обменивается
## именами/цветами игроков; транслирует пинги. Аддитивно — оффлайн ничего не делает,
## одиночная игра не меняется.

const SEND_HZ := 20.0

# Тематические имена/цвета — каждый пир берёт свои по своему id (детерминированно).
const NAMES := ["Комар", "Москит", "Жало", "Писк", "Капля", "Кровосос", "Зуд", "Пыльца"]
const COLORS := [
	Color(1.0, 0.85, 0.2), Color(0.35, 0.7, 1.0), Color(0.4, 0.9, 0.4),
	Color(0.8, 0.5, 1.0), Color(1.0, 0.55, 0.25), Color(0.3, 0.95, 0.9),
	Color(1.0, 0.5, 0.7), Color(0.7, 0.9, 0.3),
]

var _avatars: Dictionary = {}      # peer_id -> RemoteAvatar
var _identities: Dictionary = {}   # peer_id -> {name, color}  (на случай прихода до аватара)
var _peer_scores: Dictionary = {}  # peer_id -> int  (для общего финала)
var _send_accum: float = 0.0
var _clock_accum: float = 0.0
var _score_accum: float = 0.0
var _finale: bool = false

func _ready() -> void:
	add_to_group("coop")
	Net.peer_joined.connect(_on_peer_joined)
	Net.peer_left.connect(_on_peer_left)
	EventBus.run_started.connect(_on_run_started)
	EventBus.ping_made.connect(_on_ping_made)
	Clock.day_finished.connect(func(): _finale = true)

func _local_name() -> String:
	return NAMES[Net.local_id() % NAMES.size()]

func _local_color() -> Color:
	return COLORS[Net.local_id() % COLORS.size()]

func _peer_color(id: int) -> Color:
	return COLORS[id % COLORS.size()]

# Новый пир появился — представляемся ему (и всем): имя + цвет.
func _on_peer_joined(_id: int) -> void:
	if Net.is_online():
		rpc("_announce_identity", _local_name(), _local_color())

@rpc("any_peer", "reliable", "call_remote")
func _announce_identity(pname: String, color: Color) -> void:
	var id := multiplayer.get_remote_sender_id()
	_identities[id] = {"name": pname, "color": color}
	if _avatars.has(id):
		(_avatars[id] as RemoteAvatar).set_player_identity(pname, color)
	print("[Coop] игрок %d — «%s»" % [id, pname])

# --- Общие пинги: свой пинг летит остальным; чужой — на карту + 3D-маркер. ---
func _on_ping_made(player_id: int, pos: Vector3, ctx: String) -> void:
	# Только СВОЙ пинг рассылаем (чужие приходят через _recv_ping → re-emit, не зациклить).
	if Net.is_online() and player_id == Net.local_id():
		rpc("_recv_ping", pos, ctx)

@rpc("any_peer", "reliable", "call_remote")
func _recv_ping(pos: Vector3, ctx: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	_spawn_ping_marker(pos, ctx, _peer_color(id))
	EventBus.ping_made.emit(id, pos, ctx)   # id чужой → _on_ping_made не рассылает повторно
	print("[Coop] пинг от игрока %d: %s" % [id, ctx])

func _spawn_ping_marker(pos: Vector3, ctx: String, col: Color) -> void:
	var host := get_tree().current_scene
	if host == null:
		return
	var root := Node3D.new()
	host.add_child(root)
	root.global_position = pos
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.12
	cyl.height = 3.0
	beam.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	beam.material_override = mat
	beam.position = Vector3(0, 1.5, 0)
	root.add_child(beam)
	var label := Label3D.new()
	label.text = ctx
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.pixel_size = 0.01
	label.outline_size = 8
	label.modulate = col
	label.position = Vector3(0, 3.3, 0)
	root.add_child(label)
	get_tree().create_timer(GameConstants.PING_LIFE).timeout.connect(root.queue_free)

# --- Общий финал: каждый шлёт свой счёт, FinaleScreen строит таблицу. ---
@rpc("any_peer", "unreliable", "call_remote")
func _recv_score(score: int) -> void:
	_peer_scores[multiplayer.get_remote_sender_id()] = score

## Таблица очков всех игроков, отсортированная по убыванию. [{name, score, me}].
func leaderboard() -> Array:
	var rows: Array = []
	rows.append({"name": _local_name(), "score": RunState.score, "me": true})
	for id in _peer_scores:
		var nm := "Игрок %d" % id
		if _identities.has(id):
			nm = _identities[id]["name"]
		rows.append({"name": nm, "score": int(_peer_scores[id]), "me": false})
	rows.sort_custom(func(a, b): return a["score"] > b["score"])
	return rows

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
	# В финале раз в секунду шлём свой счёт — он ещё досчитывается (Баллада/доплата квеста).
	if _finale:
		_score_accum += delta
		if _score_accum >= 1.0:
			_score_accum = 0.0
			rpc("_recv_score", RunState.score)

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
		if _identities.has(id):
			var ident: Dictionary = _identities[id]
			av.set_player_identity(ident["name"], ident["color"])
		print("[Coop] аватар игрока %d создан" % id)
	(_avatars[id] as RemoteAvatar).set_target(pos, yaw)

func _on_peer_left(id: int) -> void:
	if _avatars.has(id):
		(_avatars[id] as Node).queue_free()
		_avatars.erase(id)

# --- Пистолет: толкнуть других игроков (по их аватарам шлём импульс их клиентам). ---
func push_players(origin: Vector3, dir: Vector3, reach: float, cone: float, force: float) -> void:
	if not Net.is_online():
		return
	for id in _avatars:
		var av := _avatars[id] as Node3D
		var to := av.global_position - origin
		to.y = 0.0
		var d := to.length()
		if d > reach or d < 0.1:
			continue
		if dir.dot(to / d) < cone:
			continue
		rpc_id(int(id), "_recv_knock", to.normalized() * force + Vector3(0, 5, 0))

@rpc("any_peer", "reliable", "call_remote")
func _recv_knock(impulse: Vector3) -> void:
	var p = get_tree().get_first_node_in_group("player")   # untyped → динамический вызов
	if p != null:
		p.apply_knock(impulse)
