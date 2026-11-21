class_name SquadController
extends Node2D

@export var formation_spacing: float = 24.0
@export var specialist_type: int = 0

var soldiers: Array = []
var formation_offsets: Array[Vector2] = []
var specialist_component: SpecialistComponent

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
	specialist_component = get_node_or_null("SpecialistComponent")
	if specialist_component == null:
		specialist_component = SpecialistComponent.new()
		specialist_component.name = "SpecialistComponent"
		specialist_component.specialist_type = specialist_type
		add_child(specialist_component)


func move_squad(destination: Vector2) -> void:
	for i in range(soldiers.size()):
		var offset: Vector2 = formation_offsets[i % formation_offsets.size()]
		var squad_dest: Vector2 = destination + offset
		soldiers[i].set_destination(squad_dest)

func on_soldier_died(soldier: Node2D) -> void:
	if is_instance_valid(soldier):
		soldiers.erase(soldier)
		for s in soldiers:
			if is_instance_valid(s):
				var m: MoraleComponent = s.get_node_or_null("MoraleComponent") as MoraleComponent
				if m != null:
					m.reduce_morale(20.0)
	if is_instance_valid(soldier):
		if soldier.is_in_group("enemy_units") and randf() < 0.35:
			call_deferred("_spawn_loot", soldier.global_position)
		soldier.queue_free()
	if soldiers.is_empty():
		queue_free()

func _spawn_loot(pos: Vector2) -> void:
	var crate := LootCrate.new()
	crate.loot_type = randi() % 3
	get_tree().current_scene.add_child(crate)
	crate.global_position = pos