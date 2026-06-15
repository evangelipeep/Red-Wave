extends Area3D
class_name ZoneTracker
## Зона парка: отмечает, в какой зоне сейчас игрок. Основа для «Первопроходца
## зоны» (server-auth позже). Сейчас просто пишет RunState.current_zone.

@export var zone_id: String = "klyk"

func _ready() -> void:
	add_to_group("zone")
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)

func _on_enter(body: Node3D) -> void:
	if body is PlayerController:
		RunState.current_zone = zone_id

func _on_exit(body: Node3D) -> void:
	if body is PlayerController and RunState.current_zone == zone_id:
		RunState.current_zone = ""
