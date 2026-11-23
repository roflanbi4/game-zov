class_name MissionBuilder
extends RefCounted

const _MUTANT_SPAWNER_SCRIPT := preload("res://scripts/ai/MutantWaveSpawner.gd")
const _SQUAD_SCRIPT := preload("res://scripts/core/SquadController.gd")
const _VEHICLE_SCRIPT := preload("res://scripts/units/VehicleUnit.gd")
const _DRONE_SCRIPT := preload("res://scripts/units/DroneUnit.gd")
const _CONTROL_POINT_SCRIPT := preload("res://scripts/buildings/ControlPoint.gd")

static func _mm(parent: Node) -> MissionManager:
	return parent.get_node_or_null("MissionManager") as MissionManager

static func spawn_player_squad(parent: Node, pos: Vector2, count: int = 3) -> SquadController:
	return _make_squad(parent, pos, false, count)

static func spawn_enemy_squad(parent: Node, pos: Vector2, count: int = 3) -> SquadController:
	return _make_squad(parent, pos, true, count)

static func _make_squad(parent: Node, pos: Vector2, enemy: bool, count: int) -> SquadController:
	var sq: SquadController = _SQUAD_SCRIPT.new()
	sq.position = pos
	if enemy:
		sq.add_to_group("enemy_squads")
	else:
		sq.add_to_group("player_squads")
	for i in range(count):
		var s := Soldier.new()
		s.name = "Soldier_" + str(i)
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
		rect.color = Color(0.8, 0.2, 0.2, 1) if enemy else Color(0.2, 0.9, 0.3, 1)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.add_child(rect)
		if enemy:
			s.add_to_group("enemy_units")
		else:
			s.add_to_group("player_units")
		sq.add_child(s)
	parent.call_deferred("add_child", sq)
	return sq
static func _make_vehicle(parent: Node, pos: Vector2, enemy: bool) -> VehicleUnit:
	var v := VehicleUnit.new()
	v.position = pos
	v.is_enemy = enemy
	parent.call_deferred("add_child", v)
	return v

static func _make_drone(parent: Node, pos: Vector2, dtype: int, enemy: bool) -> DroneUnit:
	var d := DroneUnit.new()
	d.position = pos
	d.drone_type = dtype
	d.is_enemy = enemy
	parent.call_deferred("add_child", d)
	return d

static func _make_anomaly(parent: Node, pos: Vector2, atype: int, radius: float) -> AnomalyZone:
	var a := AnomalyZone.new()
	a.position = pos
	a.anomaly_type = atype
	a.radius = radius
	parent.call_deferred("add_child", a)
	return a

static func _make_barrel(parent: Node, pos: Vector2) -> ExplosiveProp:
	var b := ExplosiveProp.new()
	b.position = pos
	b.explosion_radius = 200.0
	b.explosion_damage = 100
	b.hp = 50
	parent.call_deferred("add_child", b)
	return b

static func _make_artifact(parent: Node, pos: Vector2, btype: int) -> ArtifactPickup:
	var a := ArtifactPickup.new()
	a.position = pos
	a.buff_type = btype
	parent.call_deferred("add_child", a)
	return a

static func _make_control_point(parent: Node, pos: Vector2) -> ControlPoint:
	var cp := ControlPoint.new()
	cp.position = pos
	cp.capture_radius = 80.0
	cp.capture_time = 5.0
	parent.call_deferred("add_child", cp)
	return cp

static func _make_base(parent: Node, pos: Vector2, hp: int) -> StaticBody2D:
	var base := StaticBody2D.new()
	base.name = "CorpsBase"
	base.position = pos
	base.add_to_group("enemy_units")
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(140, 140)
	cs.shape = rs
	base.add_child(cs)
	var rect := ColorRect.new()
	rect.size = Vector2(140, 140)
	rect.position = Vector2(-70, -70)
	rect.color = Color(0.8, 0.1, 0.1, 1.0)
	base.add_child(rect)
	var hc := HealthComponent.new()
	hc.name = "HealthComponent"
	hc.max_hp = hp
	hc.current_hp = hp
	base.add_child(hc)
	var mm: MissionManager = parent.get_node_or_null("MissionManager") as MissionManager
	if mm != null:
		hc.died.connect(mm._on_base_destroyed)
	parent.call_deferred("add_child", base)
	return base

static func build_mission_1(parent: Node) -> void:
	var mm := _mm(parent)
	if mm != null:
		mm._set_objective("M1 [Corps]: Capture 3 control points and repel 2 mutant waves")
	spawn_player_squad(parent, Vector2(200, 400), 3)
	_make_control_point(parent, Vector2(500, 250))
	_make_control_point(parent, Vector2(1000, 540))
	_make_control_point(parent, Vector2(1400, 800))
	var spawner := MutantWaveSpawner.new()
	spawner.name = "MutantWaveSpawner"
	spawner.max_waves = 2
	spawner.wave_interval = 12.0
	spawner.spawn_points = [Vector2(1700, 200), Vector2(1700, 800)]
	spawner.swarm_count = 5
	spawner.brute_count = 1
	parent.call_deferred("add_child", spawner)

static func build_mission_2(parent: Node) -> Array[VehicleUnit]:
	var mm := _mm(parent)
	if mm != null:
		mm._set_objective("M2 [Corps]: Escort 2 trucks to extraction zone on the right")
	var trucks: Array[VehicleUnit] = []
	for i in range(2):
		var truck: VehicleUnit = _make_vehicle(parent, Vector2(200 + i * 80, 540), false)
		truck.move_speed = 80.0
		var hc: HealthComponent = truck.get_node_or_null("HealthComponent") as HealthComponent
		if hc != null:
			hc.max_hp = 400
			hc.current_hp = 400
		trucks.append(truck)
	spawn_player_squad(parent, Vector2(200, 400), 4)
	_make_anomaly(parent, Vector2(600, 300), AnomalyZone.AnomalyType.VORTEX, 140.0)
	_make_anomaly(parent, Vector2(950, 700), AnomalyZone.AnomalyType.VORTEX, 120.0)
	_make_anomaly(parent, Vector2(1300, 400), AnomalyZone.AnomalyType.VORTEX, 150.0)
	_make_barrel(parent, Vector2(550, 540))
	_make_barrel(parent, Vector2(800, 600))
	_make_barrel(parent, Vector2(1100, 500))
	_make_barrel(parent, Vector2(1400, 550))
	var extract := Area2D.new()
	extract.name = "ExtractionZone"
	extract.position = Vector2(1750, 540)
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(100, 300)
	cs.shape = rs
	extract.add_child(cs)
	parent.call_deferred("add_child", extract)
	var ai := SkirmishAI.new()
	ai.name = "SkirmishAI"
	ai.think_interval = 10.0
	ai.starting_resources = 200
	parent.call_deferred("add_child", ai)
	return trucks


static func build_mission_3(parent: Node) -> StaticBody2D:
	var mm := _mm(parent)
	if mm != null:
		mm._set_objective("M3 [Syndicate]: Night raid - destroy Corps base")
	var hud: GameHUD = parent.get_node_or_null("GameHUD") as GameHUD
	if hud != null:
		hud.set_night(true)
	_make_drone(parent, Vector2(200, 400), DroneUnit.DroneType.FPV_KAMIKAZE, false)
	_make_drone(parent, Vector2(240, 400), DroneUnit.DroneType.FPV_KAMIKAZE, false)
	spawn_player_squad(parent, Vector2(200, 350), 3)
	var base: StaticBody2D = _make_base(parent, Vector2(1500, 540), 1500)
	spawn_enemy_squad(parent, Vector2(1350, 450), 3)
	spawn_enemy_squad(parent, Vector2(1350, 650), 3)
	var ai := SkirmishAI.new()
	ai.name = "SkirmishAI"
	ai.think_interval = 12.0
	ai.starting_resources = 300
	parent.call_deferred("add_child", ai)
	return base

static func build_mission_4(parent: Node) -> void:
	var mm := _mm(parent)
	if mm != null:
		mm._set_objective("M4 [Syndicate]: Heart of the Rift - hold the artifact point for 180 sec")
	var cp: ControlPoint = _make_control_point(parent, Vector2(960, 540))
	cp.capture_time = 2.0
	_make_artifact(parent, Vector2(960, 540), ArtifactPickup.BuffType.HP)
	spawn_player_squad(parent, Vector2(200, 400), 3)
	var spawner := MutantWaveSpawner.new()
	spawner.name = "MutantWaveSpawner"
	spawner.max_waves = 999
	spawner.wave_interval = 8.0
	spawner.spawn_points = [Vector2(100, 100), Vector2(1820, 100), Vector2(100, 980), Vector2(1820, 980)]
	spawner.swarm_count = 4
	spawner.brute_count = 1
	parent.call_deferred("add_child", spawner)
	var ai := SkirmishAI.new()
	ai.name = "SkirmishAI"
	ai.think_interval = 12.0
	ai.starting_resources = 400
	parent.call_deferred("add_child", ai)

static func build_sandbox(parent: Node) -> void:
	var mm := _mm(parent)
	if mm != null:
		mm._set_objective("Sandbox: build an army and capture points")
	spawn_player_squad(parent, Vector2(200, 400), 3)
	_make_control_point(parent, Vector2(600, 300))
	_make_control_point(parent, Vector2(1300, 700))
	var ai := SkirmishAI.new()
	ai.name = "SkirmishAI"
	ai.think_interval = 15.0
	ai.starting_resources = 150
	parent.call_deferred("add_child", ai)
