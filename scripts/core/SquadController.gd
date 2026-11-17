extends Node2D

@export var formation_spacing: float = 24.0

var soldiers: Array = []
var formation_offsets: Array[Vector2] = []

func _ready() -> void:
	# Определяем группу отряда — если отряд вражеский, не считаем его игроком
	if not is_in_group("enemy_squads"):
		add_to_group("player_squads")
	
	# Создаём NavigationPolygon для навигации
	var np = NavigationPolygon.new()
	np.vertices = PackedVector2Array([Vector2(0, 0), Vector2(1920, 0), Vector2(1920, 1080), Vector2(0, 1080)])
	np.polygons = [PackedInt32Array([0, 1, 2, 3])]
	get_node("/root/Main/NavRegion").navigation_polygon = np
	
	formation_offsets = [
		Vector2(-formation_spacing, 0),
		Vector2(formation_spacing, 0),
		Vector2(0, -formation_spacing)
	]
	
	soldiers = []
	for child in get_children():
		if child is CharacterBody2D:
			soldiers.append(child)
	
	for i in range(soldiers.size()):
		if i < formation_offsets.size():
			soldiers[i].formation_offset = formation_offsets[i]

func move_squad(destination: Vector2) -> void:
	for i in range(soldiers.size()):
		var offset: Vector2 = formation_offsets[i % formation_offsets.size()]
		var squad_dest: Vector2 = destination + offset
		soldiers[i].set_destination(squad_dest)

func on_soldier_died(soldier: Node2D) -> void:
	if is_instance_valid(soldier):
		soldiers.erase(soldier)
	if is_instance_valid(soldier):
		soldier.queue_free()
	if soldiers.is_empty():
		queue_free()