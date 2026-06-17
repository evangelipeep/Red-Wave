extends Node
## Автолоад: сеть (фаза 3, первый слой). Реальный ENet host/join.
## Оффлайн (без сессии) — одиночная игра: is_server=true, local_id=1.
## Запуск для теста: `-- --host` или `-- --join` (по умолч. 127.0.0.1).

signal peer_joined(id: int)
signal peer_left(id: int)

const PORT := 24545
const MAX_PEERS := 8

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(func(): print("[Net] подключился к серверу, id=%d" % multiplayer.get_unique_id()))
	multiplayer.connection_failed.connect(func(): push_warning("[Net] не удалось подключиться"))
	var args := OS.get_cmdline_user_args()
	if "--host" in args:
		host()
	elif "--join" in args:
		join("127.0.0.1")

func host(port: int = PORT) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PEERS)
	if err != OK:
		push_warning("[Net] не удалось поднять сервер: %d" % err)
		return
	multiplayer.multiplayer_peer = peer
	print("[Net] ХОСТ на порту %d, id=%d" % [port, multiplayer.get_unique_id()])

func join(ip: String, port: int = PORT) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		push_warning("[Net] не удалось создать клиента: %d" % err)
		return
	multiplayer.multiplayer_peer = peer
	print("[Net] подключаюсь к %s:%d…" % [ip, port])

func leave() -> void:
	multiplayer.multiplayer_peer = null

func is_online() -> bool:
	return multiplayer.has_multiplayer_peer()

func is_server() -> bool:
	if is_online():
		return multiplayer.is_server()
	return true

func local_id() -> int:
	if is_online():
		return multiplayer.get_unique_id()
	return 1

func _on_peer_connected(id: int) -> void:
	print("[Net] peer +%d" % id)
	peer_joined.emit(id)

func _on_peer_disconnected(id: int) -> void:
	print("[Net] peer -%d" % id)
	peer_left.emit(id)
