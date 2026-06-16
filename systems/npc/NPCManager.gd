extends Node
## Менеджер толпы: спавнит ограниченное число NPC и раздаёт их по горкам.
## «По умному»: фиксированный пул капсул (без физики), они сами крутят цикл
## очередь→спуск→бассейн→брожение. Никакой нагрузки на хост сверх N агентов.

@export var npc_count: int = 4        # NPC, привязанные к горкам (очередь→спуск→цикл)
@export var ambient_count: int = 14   # фоновые посетители, гуляющие по парку

var _spawned: bool = false

func _ready() -> void:
	EventBus.run_started.connect(_spawn)

func _spawn() -> void:
	if _spawned:
		return
	_spawned = true
	var host := get_tree().current_scene
	var slides := get_tree().get_nodes_in_group("slide")
	# Смесь типов поведения: любители всего / за хайпом / расслабленные.
	var behaviors := [NPCAgent.Behavior.TOUR, NPCAgent.Behavior.POPULAR, NPCAgent.Behavior.CASUAL]
	for i in npc_count:
		if slides.is_empty():
			break
		var npc := NPCAgent.new()
		host.add_child(npc)
		npc.setup(behaviors[i % behaviors.size()])
	# Фоновая толпа — оживляет территорию.
	for j in ambient_count:
		host.add_child(Visitor.new())
