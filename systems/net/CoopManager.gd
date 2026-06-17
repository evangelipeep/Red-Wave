extends Node
## Кооп-синхронизация (первый слой): рассылает позицию локального игрока другим
## пирами (rpc ~20 Гц) и показывает их аватары. Аддитивно — оффлайн ничего не делает,
## одиночная игра не меняется. Синхрон состояния (Гул/квесты) — следующий шаг (server-auth).

const SEND_HZ := 20.0

var _avatars: Dictionary = {}   # peer_id -> RemoteAvatar
var _send_accum: float = 0.0

func _ready() -> void:
	Net.peer_left.connect(_on_peer_left)

func _process(delta: float) -> void:
	if not Net.is_online():
		return
	_send_accum += delta
	if _send_accum < 1.0 / SEND_HZ:
		return
	_send_accum = 0.0
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	rpc("_recv_pos", p.global_position, p.global_rotation.y)

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
