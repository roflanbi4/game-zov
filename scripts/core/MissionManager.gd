class_name MissionManager
extends Node

# Step 7: Менеджер миссий — меню выбора, сборка миссий, контроль победы/поражения.
# Все миссии, враги, мутанты и меню собираются программно на базе main_game.tscn.

enum Mission { NONE, M1, M2, M3, M4, SANDBOX }

@export var mission: Mission = Mission.NONE

var _menu: CanvasLayer
var _objective_label: Label
var _finish_overlay: Node
var _objective_text_override: String = ""

var _mission_start_time: float = 0.0
var _elapsed: float = 0.0
var _hold_duration: float = 0.0
var _finished: bool = false
var _base: StaticBody2D
var _convoy_trucks: Array[VehicleUnit] = []

func _ready() -> void:
	_menu = _build_menu()
	get_tree().root.add_child(_menu)

# --- Меню выбора миссий ---

func _build_menu() -> CanvasLayer:
	var menu := CanvasLayer.new()
	menu.name = "MissionMenu"
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	center.add_child(vbox)
	var title := Label.new()
	title.text = "EAST RIFT ZONE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	vbox.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Выбор миссии"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	vbox.add_child(subtitle)
	var missions: Array = [
		[Mission.M1, "[Корпус] Миссия 1: Периметр"],
		[Mission.M2, "[Корпус] Миссия 2: Конвой в тумане"],
		[Mission.M3, "[Синдикат] Миссия 3: Ночной налет"],
		[Mission.M4, "[Синдикат] Миссия 4: Сердце Разлома"],
	]
	for entry in missions:
		var btn := Button.new()
		btn.text = str(entry[1])
		btn.custom_minimum_size = Vector2(460, 46)
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(_on_mission_selected.bind(int(entry[0])))
		vbox.add_child(btn)
	var sandbox_btn := Button.new()
	sandbox_btn.text = "Песочница / Скирмиш"
	sandbox_btn.custom_minimum_size = Vector2(460, 46)
	sandbox_btn.add_theme_font_size_override("font_size", 18)
	sandbox_btn.pressed.connect(_on_mission_selected.bind(Mission.SANDBOX))
	vbox.add_child(sandbox_btn)
	var quit_btn := Button.new()
	quit_btn.text = "Выйти"
	quit_btn.custom_minimum_size = Vector2(460, 46)
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	vbox.add_child(quit_btn)
	return menu

func _on_mission_selected(m: int) -> void:
	_close_menu()
	await _start_mission(m)

func _close_menu() -> void:
	if is_instance_valid(_menu):
		_menu.queue_free()
		_menu = null
# --- Запуск миссии ---

func _start_mission(m: int) -> void:
	_close_menu()
	mission = m
	await get_tree().process_frame
	_clear_world()
	await get_tree().process_frame
	_build_base()
	match m:
		Mission.M1: _build_mission_1()
		Mission.M2: _build_mission_2()
		Mission.M3: _build_mission_3()
		Mission.M4: _build_mission_4()
		Mission.SANDBOX: _build_sandbox()
		_: pass
	_mission_start_time = Time.get_ticks_msec() / 1000.0

func _clear_world() -> void:
	var keep: Array[String] = ["MissionManager", "SelectionManager", "Ground", "NavRegion", "GameCamera", "Main"]
	var main: Node = get_parent()
	if main != null:
		for child in main.get_children():
			if child.name not in keep:
				child.queue_free()
	var cm = get_tree().root.get_node_or_null("CanvasModulate")
	if cm != null:
		cm.queue_free()

func _build_base() -> void:
	var eco := EconomyManager.new()
	eco.name = "EconomyManager"
	get_parent().call_deferred("add_child", eco)
	var hud := GameHUD.new()
	hud.name = "GameHUD"
	get_parent().call_deferred("add_child", hud)

	var fog := FogOfWarManager.new()
	fog.name = "FogOfWarManager"
	get_parent().call_deferred("add_child", fog)
	fog.add_to_group("fog_of_war")
	_objective_label = Label.new()
	_objective_label.name = "ObjectiveLabel"
	_objective_label.position = Vector2(230, 15)
	_objective_label.size = Vector2(400, 40)
	_objective_label.add_theme_font_size_override("font_size", 20)
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_objective_label.modulate = Color.WHITE
	hud.add_child(_objective_label)

func _set_objective(text: String) -> void:
	_objective_text_override = text
	if is_instance_valid(_objective_label):
		_objective_label.text = "ЦЕЛЬ: " + text
func _build_sandbox() -> void:
	_set_objective("Песочница: постройте армию и захватите точки")
	_make_squad(Vector2(200, 400), false, 3)
	_make_control_point(Vector2(600, 300))
	_make_control_point(Vector2(1300, 700))
	var ai := SkirmishAI.new()
	ai.name = "SkirmishAI"
	ai.think_interval = 15.0
	ai.starting_resources = 150
	get_parent().call_deferred("add_child", ai)
func _build_mission_1() -> void:
	_set_objective("M1 [Корпус]: Захватить 3 контрольные точки и отбить 2 волны мутантов")
	_make_squad(Vector2(200, 400), false, 3)
	_make_control_point(Vector2(500, 250))
	_make_control_point(Vector2(1000, 540))
	_make_control_point(Vector2(1400, 800))
	var spawner := MutantWaveSpawner.new()
	spawner.name = "MutantWaveSpawner"
	spawner.max_waves = 2
	spawner.wave_interval = 12.0
	spawner.spawn_points = [Vector2(1700, 200), Vector2(1700, 800)]
	spawner.swarm_count = 5
	spawner.brute_count = 1
	get_parent().call_deferred("add_child", spawner)

func _build_mission_2() -> void:
	_set_objective("M2 [Корпус]: Провести 2 грузовика в зону эвакуации справа")
	_convoy_trucks = []
	for i in range(2):
		var truck := _make_vehicle(Vector2(200 + i * 80, 540), false)
		truck.move_speed = 80.0
		var hc := truck.get_node_or_null("HealthComponent") as HealthComponent
		if hc != null:
			hc.max_hp = 400
			hc.current_hp = 400
		_convoy_trucks.append(truck)
	_make_squad(Vector2(200, 400), false, 4)
	_make_anomaly(Vector2(600, 300), AnomalyZone.AnomalyType.VORTEX, 140.0)
	_make_anomaly(Vector2(950, 700), AnomalyZone.AnomalyType.VORTEX, 120.0)
	_make_anomaly(Vector2(1300, 400), AnomalyZone.AnomalyType.VORTEX, 150.0)
	_make_barrel(Vector2(550, 540))
	_make_barrel(Vector2(800, 600))
	_make_barrel(Vector2(1100, 500))
	_make_barrel(Vector2(1400, 550))
	var extract := Area2D.new()
	extract.name = "ExtractionZone"
	extract.position = Vector2(1750, 540)
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(100, 300)
	cs.shape = rs
	extract.add_child(cs)
	get_parent().call_deferred("add_child", extract)
	var ai := SkirmishAI.new()
	ai.name = "SkirmishAI"
	ai.think_interval = 10.0
	ai.starting_resources = 200
	get_parent().call_deferred("add_child", ai)
func _build_mission_3() -> void:
	_set_objective("M3 [Синдикат]: Ночной налет — уничтожить базу Корпуса")
	var hud: GameHUD = get_parent().get_node_or_null("GameHUD") as GameHUD
	if hud != null:
		hud.set_night(true)
	_make_drone(Vector2(200, 400), DroneUnit.DroneType.FPV_KAMIKAZE, false)
	_make_drone(Vector2(240, 400), DroneUnit.DroneType.FPV_KAMIKAZE, false)
	_make_squad(Vector2(200, 350), false, 3)
	_base = _make_base(Vector2(1500, 540), 1500)
	_make_squad(Vector2(1350, 450), true, 3)
	_make_squad(Vector2(1350, 650), true, 3)
	var ai := SkirmishAI.new()
	ai.name = "SkirmishAI"
	ai.think_interval = 12.0
	ai.starting_resources = 300
	get_parent().call_deferred("add_child", ai)

func _build_mission_4() -> void:
	_set_objective("M4 [Синдикат]: Сердце Разлома — удержать точку с артефактом 180 сек")
	var cp := _make_control_point(Vector2(960, 540))
	cp.capture_time = 2.0
	_make_artifact(Vector2(960, 540), ArtifactPickup.BuffType.HP)
	_make_squad(Vector2(200, 400), false, 3)
	var spawner := MutantWaveSpawner.new()
	spawner.name = "MutantWaveSpawner"
	spawner.max_waves = 999
	spawner.wave_interval = 8.0
	spawner.spawn_points = [Vector2(100, 100), Vector2(1820, 100), Vector2(100, 980), Vector2(1820, 980)]
	spawner.swarm_count = 4
	spawner.brute_count = 1
	get_parent().call_deferred("add_child", spawner)
	var ai := SkirmishAI.new()
	ai.name = "SkirmishAI"
	ai.think_interval = 12.0
	ai.starting_resources = 400
	get_parent().call_deferred("add_child", ai)

# --- Фабрики юнитов и объектов ---

const _SQUAD_SCRIPT := preload("res://scripts/core/SquadController.gd")

func _make_squad(pos: Vector2, enemy: bool, count: int = 3) -> Node2D:
	var sq: Node2D = _SQUAD_SCRIPT.new()
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
	get_parent().call_deferred("add_child", sq)
	return sq

func _make_vehicle(pos: Vector2, enemy: bool) -> VehicleUnit:
	var v := VehicleUnit.new()
	v.position = pos
	v.is_enemy = enemy
	get_parent().call_deferred("add_child", v)
	return v

func _make_drone(pos: Vector2, dtype: int, enemy: bool) -> DroneUnit:
	var d := DroneUnit.new()
	d.position = pos
	d.drone_type = dtype
	d.is_enemy = enemy
	get_parent().call_deferred("add_child", d)
	return d

func _make_anomaly(pos: Vector2, atype: int, radius: float) -> AnomalyZone:
	var a := AnomalyZone.new()
	a.position = pos
	a.anomaly_type = atype
	a.radius = radius
	get_parent().call_deferred("add_child", a)
	return a

func _make_barrel(pos: Vector2) -> ExplosiveProp:
	var b := ExplosiveProp.new()
	b.position = pos
	b.explosion_radius = 200.0
	b.explosion_damage = 100
	b.hp = 50
	get_parent().call_deferred("add_child", b)
	return b

func _make_artifact(pos: Vector2, btype: int) -> ArtifactPickup:
	var a := ArtifactPickup.new()
	a.position = pos
	a.buff_type = btype
	get_parent().call_deferred("add_child", a)
	return a

func _make_control_point(pos: Vector2) -> ControlPoint:
	var cp := ControlPoint.new()
	cp.position = pos
	cp.capture_radius = 80.0
	cp.capture_time = 5.0
	get_parent().call_deferred("add_child", cp)
	return cp

func _make_base(pos: Vector2, hp: int) -> StaticBody2D:
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
	hc.died.connect(_on_base_destroyed)
	get_parent().call_deferred("add_child", base)
	return base

func _on_base_destroyed(_node: Node2D) -> void:
	if mission == Mission.M3:
		_finish(true)
# --- Проверка условий победы/поражения ---

func _process(delta: float) -> void:
	if mission == Mission.NONE:
		return
	_elapsed += delta
	_update_objective()
	_check_win_lose(delta)

func _update_objective() -> void:
	if not is_instance_valid(_objective_label):
		return
	var text: String = _objective_text()
	if text != "":
		_objective_label.text = text

func _objective_text() -> String:
	match mission:
		Mission.M1:
			return "ЦЕЛЬ: Захват точек " + str(_captured_points()) + "/3 и отбивание 2 волн мутантов"
		Mission.M2:
			return "ЦЕЛЬ: Грузовиков в зоне эвакуации: " + str(_trucks_in_zone()) + "/2"
		Mission.M3:
			var base_dead: bool = _base == null or not is_instance_valid(_base)
			return "ЦЕЛЬ: Уничтожить базу Корпуса" + (" — ВЫПОЛНЕНО" if base_dead else "")
		Mission.M4:
			var owned: bool = _center_point_owned()
			return "ЦЕЛЬ: Удержание точки " + str(int(_hold_duration)) + "/180 сек" + ("" if owned else " (точка не удержана)")
		Mission.SANDBOX:
			return "Песочница: свободная игра"
	return ""

func _captured_points() -> int:
	var c: int = 0
	for cp in get_tree().get_nodes_in_group("control_points"):
		if is_instance_valid(cp) and cp.point_owner == ControlPoint.Owner.PLAYER:
			c += 1
	return c

func _trucks_in_zone() -> int:
	var c: int = 0
	for t in _convoy_trucks:
		if is_instance_valid(t) and t.global_position.x > 1650.0:
			c += 1
	return c

func _center_point_owned() -> bool:
	for cp in get_tree().get_nodes_in_group("control_points"):
		if is_instance_valid(cp) and cp.point_owner == ControlPoint.Owner.PLAYER:
			return true
	return false

func _player_units_alive() -> bool:
	if not get_tree().get_nodes_in_group("player_units").is_empty():
		return true
	if not get_tree().get_nodes_in_group("player_drones").is_empty():
		return true
	return false

func _check_win_lose(delta: float) -> void:
	if _elapsed < 3.0:
		return
	match mission:
		Mission.M1:
			var sp: MutantWaveSpawner = get_parent().get_node_or_null("MutantWaveSpawner") as MutantWaveSpawner
			var waves_done: bool = sp != null and sp._done
			var mutants_alive: int = 0
			if sp != null:
				mutants_alive = int(sp.call("alive_mutants"))
			if _captured_points() >= 3 and waves_done and mutants_alive == 0:
				_finish(true)
				return
		Mission.M2:
			if _trucks_in_zone() >= 2:
				_finish(true)
				return
		Mission.M3:
			if _base == null or not is_instance_valid(_base):
				_finish(true)
				return
		Mission.M4:
			if _center_point_owned():
				_hold_duration += delta
				if _hold_duration >= 180.0:
					_finish(true)
					return
		Mission.SANDBOX:
			pass
	if _elapsed > 2.0 and not _player_units_alive():
		_finish(false)

func _finish(won: bool) -> void:
	if _finished:
		return
	_finished = true
	mission = Mission.NONE
	_show_finish(won)

func _show_finish(won: bool) -> void:
	var layer := CanvasLayer.new()
	layer.name = "FinishOverlay"
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)
	var title := Label.new()
	title.text = "ПОБЕДА!" if won else "ПОРАЖЕНИЕ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4) if won else Color(1.0, 0.3, 0.3))
	vbox.add_child(title)
	var btn := Button.new()
	btn.text = "В меню выбора миссий"
	btn.custom_minimum_size = Vector2(300, 50)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(func() -> void: get_tree().reload_current_scene())
	vbox.add_child(btn)
	get_parent().add_child(layer)
	_finish_overlay = layer
