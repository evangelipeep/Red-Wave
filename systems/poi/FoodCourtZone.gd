extends Area3D
class_name FoodCourtZone
## Зона фуд-корта: держит флаг RunState.in_food_court (еду можно есть только тут).
## Срабатывает ТОЛЬКО на локального игрока (PlayerController) — NPC/удалённые аватары
## не считаются. При выходе с непустым подносом предупреждает: еду выносить нельзя.

func _ready() -> void:
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)

func _on_enter(body: Node3D) -> void:
	if body is PlayerController:
		RunState.in_food_court = true

func _on_exit(body: Node3D) -> void:
	if body is PlayerController:
		RunState.in_food_court = false
		if not RunState.trays.is_empty():
			EventBus.toast.emit("Еду нельзя выносить с фуд-корта — доешьте или выбросите.")
