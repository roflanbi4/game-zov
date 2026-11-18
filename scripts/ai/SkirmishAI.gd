class_name SkirmishAI
extends Node

# Step 7: Скирмиш-ИИ — копит ресурсы, спавнит вражеские отряды/технику, атакует.

const _SQUAD_SCRIPT := preload("res://scripts/core/SquadController.gd")

@export var think_interval: float = 15.0
@export var starting_resources: int = 150

var _resources: int = 150
var _timer: float = 0.0
var _spawned_squads: int = 0

signal resources_changed(amount: int)

func _ready() -> void:
	_resources = starting_resources

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= think_interval:
		_timer = 0.0
		_generate_resources()
		_try_spawn()

func _generate_resources() -> void:
	_resources += 60
	resources_changed.emit(_resources)

func _try_spawn() -> void:
	if _resources < 75:
		return
	if get_tree().get_nodes_in_group("enemy_squads").size() > 6:
		return
	var target: Node2D = _nearest_enemy_target()
	if _resources >= 100:
		_spawn_enemy_squad()
		_resources -= 100
	elif _resources >= 250:
		_spawn_enemy_vehicle()
		_resources -= 250
	elif _resources >= 75:
		_spawn_enemy_drone()
		_resources -= 75
	elif _resources >= 350:
		_spawn_enemy_squad()
		_resources -= 100
	if target != null and is_instance_valid(target):
		var squads: Array = get_tree().get_nodes_in_group("enemy_squads")
		var last: Node2D = null
		for s in squads:
			if is_instance_valid(s) and s != last:
				last = s
				if last.has_method("move_squad"):
					last.move_squad(target.global_position)

func _spawn_enemy_squad() -> void:
	var squad: Node2D = _SQUAD_SCRIPT.new()
	squad.name = "EnemySquad_" + str(_spawned_squads)
	_spawned_squads += 1
	squad.position = Vector2(900 + randi_range(0, 300), 300 + randi_range(0, 300))
	squad.add_to_group("enemy_squads")
	for i in range(3):
		var s := Soldier.new()
		s.name = "EnemySoldier_" + str(i)
		s.position = Vector2(i * 24 - 24, 0)
		var nav := NavigationAgent2D.new()
		nav.name = "NavigationAgent2D"
		s.add_child(nav)
		var cs := CollisionShape2D.new()
		var circ := CircleShape2D.new()
		circ.radius = 6.0
		cs.shape = circ
		s.add_child(cs)
		var rect := ColorRect.new()
		rect.size = Vector2(16, 16)
		rect.position = Vector2(-8, -8)
		rect.color = Color(0.8, 0.2, 0.2, 1)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.add_child(rect)
		s.add_to_group("enemy_units")
		squad.add_child(s)
	get_parent().add_child(squad)

func _spawn_enemy_vehicle() -> void:
	var v := VehicleUnit.new()
	v.name = "EnemyVehicle_" + str(_spawned_squads)
	v.position = Vector2(1000, 500)
	v.is_enemy = true
	get_parent().add_child(v)

func _spawn_enemy_drone() -> void:
	var d := DroneUnit.new()
	d.name = "EnemyDrone_" + str(_spawned_squads)
	d.position = Vector2(1000, 500)
	d.drone_type = DroneUnit.DroneType.FPV_KAMIKAZE
	d.is_enemy = true
	get_parent().add_child(d)

func _nearest_enemy_target() -> Node2D:
	var origin: Vector2 = Vector2(960.0, 540.0)
	var best: Node2D = null
	var best_d: float = INF
	for cp in get_tree().get_nodes_in_group("control_points"):
		var d: float = origin.distance_to(cp.global_position)
		if d < best_d:
			best_d = d
			best = cp
	for n in get_tree().get_nodes_in_group("player_units"):
		var d2: float = origin.distance_to(n.global_position)
		if d2 < best_d:
			best_d = d2
			best = n
	return best