extends Node
## Автолоад: сеть. СТАБ фазы 1 — эмулирует «сервер = это устройство», один
## локальный игрок с id=1. В фазе 3 станет настоящим авторитетом (server-auth).

const LOCAL_ID := 1

func is_server() -> bool:
	return true

func local_id() -> int:
	return LOCAL_ID
