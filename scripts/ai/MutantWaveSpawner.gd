class_name MutantWaveSpawner
extends Node

# Step 7: Спавнер волн мутантов (Swarmers — быстрые ближники, Brutes — тяжёлые)
# Мутанты создаются как SquadController (группы "mutants" + "enemy_squads"),
# поэтому Soldier._ready корректно кладёт бойцов в группу "enemy_units".

const _SQUAD_SCRIPT := preload("res://scripts/core/SquadController.gd")

@export var swarm_count: int = 6
@export var brute_count: int = 2
@export var wave_interval: float = 10.0
@export var max_waves: int = 3
@export var spawn_points: Array = [Vector2(1700, 200), Vector2(1700, 800)]

signal wave_spawned(wave_number: int)
signal all_waves_spawned()

var _wave: int = 0
var _timer: float = 3.0
var _retarget: float = 0.0
var _done: bool = false

func _process(delta: float) -> void:
	if _done:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = wave_interval
		_spawn_wave()
	_retarget += delta
	if _retarget >= 1.0:
		_retarget = 0.0
		_retarget_mutants()

func _spawn_wave() -> void:
	_wave += 1
	wave_spawned.emit(_wave)
	var base: Vector2 = spawn_points[_wave % spawn_points.size()]
	for i in range(swarm_count):
		_make_mutant("swarmer", base + Vector2(i * 30, i * 18))
	for i in range(brute_count):
		_make_mutant("brute", base + Vector2(i * 60, 120 + i * 40))
	if _wave >= max_waves:
		_done = true
		all_waves_spawned.emit()

func _make_mutant(kind: String, pos: Vector2) -> void:
	var pack: Node2D = _SQUAD_SCRIPT.new()
	pack.name = "MutantPack_" + kind + str(_wave) + "_" + str(randi())
	pack.position = pos
	pack.add_to_group("mutants")
	pack.add_to_group("enemy_squads")
	var s := Soldier.new()
	s.name = "Mutant"
	var nav := NavigationAgent2D.new()
	nav.name = "NavigationAgent2D"
	s.add_child(nav)
	var cs := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 6.0
	cs.shape = circ
	s.add_child(cs)
	var rect := ColorRect.new()
	var hp: int = 40
	var spd: float = 300.0
	# Ближний бой: скорость атаки 28.0, пуль 2000.0
	var dmg: int = 25
	var cd: float = 0.6
	if kind == "brute":
		rect.size = Vector2(30, 30)
		rect.position = Vector2(-15, -15)
		rect.color = Color(0.55, 0.1, 0.75)
		hp = 260
		spd = 90.0
		dmg = 45
		cd = 1.4
	else:
		rect.size = Vector2(14, 14)
		rect.position = Vector2(-7, -7)
		rect.color = Color(0.75, 0.3, 1.0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.add_child(rect)
	var hc := HealthComponent.new()
	hc.name = "HealthComponent"
	hc.max_hp = hp
	s.add_child(hc)
	var wc := WeaponComponent.new()
	wc.name = "WeaponComponent"
	# Ближний бой: урон мгновенно, без пуль
	wc.attack_range = 42.0 if kind == "brute" else 34.0
	wc.attack_damage = dmg
	wc.attack_cooldown = cd
	wc.projectile_speed = 2000.0
	wc.target_group = "player_units"
	s.add_child(wc)
	pack.add_child(s)
	# Присвоим скорость movement
	s.move_speed = spd
	get_parent().add_child(pack)

func _retarget_mutants() -> void:
	for pack in get_tree().get_nodes_in_group("mutants"):
		if not is_instance_valid(pack) or not (pack is Node2D):
			continue
		for s in pack.get("soldiers"):
			if not is_instance_valid(s):
				continue
			var best := _nearest_foe(s)
			if best == null:
				continue
			# Используем move_squad у пака, если доступен
			if pack.has_method("move_squad"):
				pack.move_squad(best.global_position)
			else:
				s.set_destination(best.global_position)
			var w := s.get_node_or_null("WeaponComponent") as WeaponComponent
			if w != null:
				w.target_group = "player_units" if best.is_in_group("player_units") else "enemy_units"

func _nearest_foe(from: Node2D) -> Node2D:
	var best: Node2D = null
	var best_d: float = INF
	for g in ["player_units", "enemy_units"]:
		for n in get_tree().get_nodes_in_group(g):
			if not is_instance_valid(n) or n == from or n.is_in_group("mutants"):
				continue
			var d: float = from.global_position.distance_squared_to(n.global_position)
			if d < best_d:
				best_d = d
				best = n
	return best

func alive_mutants() -> int:
	var c: int = 0
	for pack in get_tree().get_nodes_in_group("mutants"):
		if is_instance_valid(pack) and (pack is Node2D):
			var arr: Array = pack.get("soldiers")
			if arr != null:
				c += arr.size()
	return c
