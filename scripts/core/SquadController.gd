class_name SquadController
extends Node2D

const _CFG := preload("res://scripts/core/GameConfig.gd")

@export var formation_spacing: float = 24.0
@export var formation: int = 0
@export var specialist_type: int = 0

enum Formation { LINE = 0, COLUMN = 1, WEDGE = 2, SPREAD = 3 }

var soldiers: Array = []
var formation_offsets: Array[Vector2] = []
var specialist_component: SpecialistComponent

func _ready() -> void:
	# Определяем группу отряда — если отряд вражеский, не считаем его игроком
	if not is_in_group("enemy_squads"):
		add_to_group("player_squads")
	
	# Создаём NavigationPolygon для навигации, только если сетка ещё не задана
	var nav_region: NavigationRegion2D = get_node("/root/Main/NavRegion") as NavigationRegion2D
	if nav_region.navigation_polygon == null:
		var np = NavigationPolygon.new()
		np.vertices = PackedVector2Array([Vector2(0, 0), Vector2(_CFG.MAP_WIDTH, 0), Vector2(_CFG.MAP_WIDTH, _CFG.MAP_HEIGHT), Vector2(0, _CFG.MAP_HEIGHT)])
		np.polygons = [PackedInt32Array([0, 1, 2, 3])]
		nav_region.navigation_polygon = np
	
	formation_offsets = []
	_update_formation_offsets()
	
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
	var squad_center: Vector2 = Vector2.ZERO
	var valid_count: int = 0
	for i in range(soldiers.size()):
		if is_instance_valid(soldiers[i]):
			squad_center += soldiers[i].global_position
			valid_count += 1
	if valid_count > 0:
		squad_center /= float(valid_count)
	var dir: Vector2 = (destination - squad_center)
	var rotate_angle: float = 0.0
	if dir.length() > 1.0:
		rotate_angle = dir.angle()
	for i in range(soldiers.size()):
		if not is_instance_valid(soldiers[i]):
			continue
		var offset: Vector2 = formation_offsets[i % formation_offsets.size()].rotated(rotate_angle)
		var squad_dest: Vector2 = destination + offset
		soldiers[i].set_destination(squad_dest)

func _update_formation_offsets() -> void:
	formation_offsets = []
	match formation:
		Formation.LINE:
			formation_offsets = [
				Vector2(0.0, -formation_spacing),
				Vector2.ZERO,
				Vector2(0.0, formation_spacing)
			]
		Formation.COLUMN:
			formation_offsets = [
				Vector2(-formation_spacing, 0.0),
				Vector2.ZERO,
				Vector2(formation_spacing, 0.0)
			]
		Formation.WEDGE:
			formation_offsets = [
				Vector2(-formation_spacing, -formation_spacing),
				Vector2.ZERO,
				Vector2(formation_spacing, -formation_spacing)
			]
		Formation.SPREAD:
			formation_offsets = [
				Vector2(-formation_spacing * 1.5, -formation_spacing),
				Vector2.ZERO,
				Vector2(formation_spacing * 1.5, -formation_spacing)
			]
		_:
			formation_offsets = [
				Vector2(0.0, -formation_spacing),
				Vector2.ZERO,
				Vector2(0.0, formation_spacing)
			]

func set_formation(new_formation: int) -> void:
	formation = new_formation
	_update_formation_offsets()
	for i in range(soldiers.size()):
		if i < formation_offsets.size() and is_instance_valid(soldiers[i]):
			soldiers[i].formation_offset = formation_offsets[i]

func hold() -> void:
	for i in range(soldiers.size()):
		if is_instance_valid(soldiers[i]) and soldiers[i].has_method("hold"):
			soldiers[i].hold()

func stop() -> void:
	for i in range(soldiers.size()):
		if is_instance_valid(soldiers[i]) and soldiers[i].has_method("stop"):
			soldiers[i].stop()

func set_attack_move(enabled: bool) -> void:
	for i in range(soldiers.size()):
		if is_instance_valid(soldiers[i]) and soldiers[i].has_method("set_attack_move"):
			soldiers[i].set_attack_move(enabled)

func on_soldier_died(soldier: Node2D) -> void:
	if is_instance_valid(soldier):
		soldiers.erase(soldier)
		for s in soldiers:
			if is_instance_valid(s):
				var m: MoraleComponent = s.get_node_or_null("MoraleComponent") as MoraleComponent
				if m != null:
					m.reduce_morale(20.0)
	if is_instance_valid(soldier):
		var stain_pos: Vector2 = soldier.global_position
		if soldier.is_in_group("enemy_units") and randf() < 0.35:
			call_deferred("_spawn_loot", stain_pos)
		var stain := ColorRect.new()
		stain.size = Vector2(14.0, 14.0)
		stain.position = stain_pos - Vector2(7.0, 7.0)
		stain.color = Color(0.35, 0.05, 0.05, 0.65)
		stain.z_index = 1
		stain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stain.add_to_group("mission_cleanup")
		if get_tree() != null and get_tree().current_scene != null:
			get_tree().current_scene.add_child(stain)
		var stain_tween := stain.create_tween()
		stain_tween.tween_property(stain, "modulate:a", 0.0, 8.0)
		stain_tween.tween_callback(stain.queue_free)
		soldier.queue_free()
	if soldiers.is_empty():
		queue_free()

func _spawn_loot(pos: Vector2) -> void:
	var crate := LootCrate.new()
	crate.loot_type = randi() % 3
	get_tree().current_scene.add_child(crate)
	crate.global_position = pos