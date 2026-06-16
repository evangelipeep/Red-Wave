extends Node
## Менеджер толпы: спавнит ограниченное число NPC и раздаёт их по горкам.
## «По умному»: фиксированный пул капсул (без физики), они сами крутят цикл
## очередь→спуск→бассейн→брожение. Никакой нагрузки на хост сверх N агентов.

@export var npc_count: int = 4

var _spawned: bool = false

func _ready() -> void:
	EventBus.run_started.connect(_spawn)

func _spawn() -> void:
	if _spawned:
		return
	_spawned = true
	var slides := get_tree().get_nodes_in_group("slide")
	if slides.is_empty():
		return
	var host := get_tree().current_scene
	for i in npc_count:
		var npc := NPCAgent.new()
		host.add_child(npc)
		npc.setup(slides[i % slides.size()])
