class_name HUDReinforcementPanel
extends Control

const _SQUAD_SCRIPT := preload("res://scripts/core/SquadController.gd")
const _VEHICLE_SCRIPT := preload("res://scripts/units/VehicleUnit.gd")
const _DRONE_SCRIPT := preload("res://scripts/units/DroneUnit.gd")
const _SPECIALIST_SCRIPT := preload("res://scripts/components/SpecialistComponent.gd")

const COST_INFANTRY: int = 100
const COST_VETERAN: int = 220
const COST_SAPPER: int = 80
const COST_MEDIC: int = 80
const COST_RADIO: int = 90
const COST_AT: int = 140
const COST_VEHICLE: int = 250
const COST_DRONE: int = 75
const COST_EW: int = 220
const COST_FLARE: int = 30

var _eco: EconomyManager
var _grid: GridContainer

var _infantry_btn: Button
var _veteran_btn: Button
var _sapper_btn: Button
var _medic_btn: Button
var _radio_btn: Button
var _at_btn: Button
var _vehicle_btn: Button
var _drone_btn: Button
var _ew_btn: Button
var _flare_btn: Button




func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_eco = get_tree().get_first_node_in_group("economy") as EconomyManager
	_grid = GridContainer.new()
	_grid.columns = 5
	var vp_height: float = get_viewport().get_visible_rect().size.y
	if vp_height <= 0.0:
		vp_height = 1080.0
	_grid.position = Vector2(10.0, vp_height - 95.0)
	add_child(_grid)

	_infantry_btn = _make_btn("Infantry (100 SP)", "Hire cheap 3-man recruit squad", _on_infantry)
	_veteran_btn = _make_btn("Veterans (220 SP)", "Experienced squad with better aim and morale", _on_veteran_squad)
	_sapper_btn = _make_btn("Sapper (80 SP)", "Sapper: mines, wire, anomaly disarming", _on_sapper)
	_medic_btn = _make_btn("Medic (80 SP)", "Attach medic to selected squad", _on_medic)
	_radio_btn = _make_btn("Radio (90 SP)", "Radio operator: artillery, smoke, extended range", _on_radio)
	_at_btn = _make_btn("AT Squad (140 SP)", "Squad with anti-tank weapons against vehicles", _on_at)
	_vehicle_btn = _make_btn("APC (250 SP)", "Armored vehicle with machinegun", _on_vehicle)
	_drone_btn = _make_btn("FPV Drone (75 SP)", "FPV kamikaze: high-speed suicide drone", _on_drone)
	_ew_btn = _make_btn("EW Station (220 SP)", "Electronic warfare jammer vehicle", _on_ew_station)
	_flare_btn = _make_btn("Flare (30 SP)", "Illuminate area at night", _on_flare)

func _make_btn(text: String, tooltip: String, callable: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.tooltip_text = tooltip
	btn.pressed.connect(callable)
	_grid.add_child(btn)
	return btn

func _on_infantry() -> void:
	if _eco != null and _eco.spend_sp(COST_INFANTRY):
		_spawn_soldier_squad(3)

func _on_veteran_squad() -> void:
	if _eco != null and _eco.spend_sp(COST_VETERAN):
		_spawn_veteran_squad()

func _on_sapper() -> void:
	var target_squad: Node2D = _get_selected_squad()
	if not _can_add_specialist(target_squad):
		return
	if _eco != null and _eco.spend_sp(COST_SAPPER):
		_attach_specialist_to_selected(SpecialistComponent.Type.SAPPER)

func _on_medic() -> void:
	var target_squad: Node2D = _get_selected_squad()
	if not _can_add_specialist(target_squad):
		return
	if _eco != null and _eco.spend_sp(COST_MEDIC):
		_attach_specialist_to_selected(SpecialistComponent.Type.MEDIC)

func _on_radio() -> void:
	var target_squad: Node2D = _get_selected_squad()
	if not _can_add_specialist(target_squad):
		return
	if _eco != null and _eco.spend_sp(COST_RADIO):
		_attach_specialist_to_selected(SpecialistComponent.Type.RADIO)

func _on_at() -> void:
	if _eco != null and _eco.spend_sp(COST_AT):
		_spawn_at_squad()

func _on_vehicle() -> void:
	if _eco != null and _eco.spend_sp(COST_VEHICLE):
		_spawn_vehicle()

func _on_drone() -> void:
	if _eco != null and _eco.spend_sp(COST_DRONE):
		_spawn_drone()

func _on_ew_station() -> void:
	if _eco != null and _eco.spend_sp(COST_EW):
		_spawn_ew_vehicle()

func _on_flare() -> void:
	var ability_panel: HUDAbilityPanel = get_parent().get_node_or_null("HUDAbilityPanel") as HUDAbilityPanel
	if ability_panel != null:
		ability_panel.enable_flare_mode()
	else:
		var ability_panel2: HUDAbilityPanel = get_tree().current_scene.find_child("HUDAbilityPanel", true, false) as HUDAbilityPanel
		if ability_panel2 != null:
			ability_panel2.enable_flare_mode()
		else:
			_show_notification("Click on map for rocket")


func _get_selected_squad() -> Node2D:
	var sel_mgr: Node = get_tree().current_scene.get_node_or_null("SelectionManager")
	if sel_mgr != null:
		var selected: Array = sel_mgr.get("selected_squads")
		if selected != null and selected.size() > 0 and is_instance_valid(selected[0]):
			return selected[0] as Node2D
	return null

func _can_add_specialist(target_squad: Node2D) -> bool:
	if target_squad == null:
		_show_notification("First select a squad!")
		return false
	var spec: SpecialistComponent = target_squad.get_node_or_null("SpecialistComponent") as SpecialistComponent
	if spec != null and spec.specialist_type != SpecialistComponent.Type.NONE:
		_show_notification("Squad already has a specialist!")
		return false
	return true

func _attach_specialist_to_selected(spec_type: int) -> void:
	var target_squad: Node2D = _get_selected_squad()
	if target_squad == null:
		_show_notification("First select a squad!")
		return
	var spec: SpecialistComponent = target_squad.get_node_or_null("SpecialistComponent") as SpecialistComponent
	if spec != null and spec.specialist_type != SpecialistComponent.Type.NONE:
		_show_notification("Squad already has a specialist!")
		return
	if spec == null:
		spec = SpecialistComponent.new()
		spec.name = "SpecialistComponent"
		target_squad.add_child(spec)
	spec.specialist_type = spec_type
	spec._ready()
	var type_name: String = "Specialist"
	match spec_type:
		SpecialistComponent.Type.MEDIC: type_name = "Medic"
		SpecialistComponent.Type.SAPPER: type_name = "Sapper"
		SpecialistComponent.Type.RADIO: type_name = "Radio"
	_show_notification(type_name + " added to squad!")

func _show_notification(text: String) -> void:
	var hud: Node = get_tree().get_first_node_in_group("game_hud")
	if hud != null and hud.has_method("_show_notification"):
		hud.call("_show_notification", text)

func _get_free_spawn_pos(origin: Vector2 = Vector2(200.0, 400.0)) -> Vector2:
	var groups_to_check: Array[String] = ["player_units", "player_vehicles", "player_drones"]
	for attempt in range(50):
		var dx: int = (attempt % 7) - 3
		var dy: int = int(float(attempt) / 7.0) - 3
		var candidate: Vector2 = origin + Vector2(dx * 65.0, dy * 65.0)
		if candidate.x < 60.0 or candidate.x > 1860.0 or candidate.y < 60.0 or candidate.y > 1020.0:
			continue
		var overlap: bool = false
		for g in groups_to_check:
			for node in get_tree().get_nodes_in_group(g):
				if is_instance_valid(node) and node is Node2D:
					if (node as Node2D).global_position.distance_to(candidate) < 60.0:
						overlap = true
						break
			if overlap:
				break
		if not overlap:
			return candidate
	return origin

func _spawn_soldier_squad(count: int) -> void:
	var squad = _SQUAD_SCRIPT.new()
	squad.position = _get_free_spawn_pos()
	for i in range(count):
		var soldier := Soldier.new()
		soldier.name = "Soldier_" + str(i)
		soldier.position = Vector2(i * 24 - 24, 0)
		var nav := NavigationAgent2D.new()
		nav.name = "NavigationAgent2D"
		soldier.add_child(nav)
		var cs := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 6.0
		cs.shape = circle
		soldier.add_child(cs)
		var rect := ColorRect.new()
		rect.size = Vector2(16.0, 16.0)
		rect.position = Vector2(-8.0, -8.0)
		rect.color = Color.BLUE
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		soldier.add_child(rect)
		squad.add_child(soldier)
		soldier.add_to_group("player_units")
	get_tree().current_scene.call_deferred("add_child", squad)

func _spawn_veteran_squad() -> void:
	var squad = _SQUAD_SCRIPT.new()
	squad.position = _get_free_spawn_pos()
	for i in range(3):
		var soldier := Soldier.new()
		soldier.name = "VetSoldier_" + str(i)
		soldier.position = Vector2(i * 24 - 24, 0)
		var nav := NavigationAgent2D.new()
		nav.name = "NavigationAgent2D"
		soldier.add_child(nav)
		var cs := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 6.0
		cs.shape = circle
		soldier.add_child(cs)
		var rect := ColorRect.new()
		rect.size = Vector2(16.0, 16.0)
		rect.position = Vector2(-8.0, -8.0)
		rect.color = Color(0.15, 0.55, 1.0)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		soldier.add_child(rect)
		squad.add_child(soldier)
		soldier.add_to_group("player_units")
	get_tree().current_scene.call_deferred("add_child", squad)
	call_deferred("_grant_veteran_xp", squad)

func _spawn_at_squad() -> void:
	var squad = _SQUAD_SCRIPT.new()
	squad.position = _get_free_spawn_pos()
	for i in range(3):
		var soldier := Soldier.new()
		soldier.name = "AT_Soldier_" + str(i)
		soldier.position = Vector2(i * 24 - 24, 0)
		var nav := NavigationAgent2D.new()
		nav.name = "NavigationAgent2D"
		soldier.add_child(nav)
		var cs := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 6.0
		cs.shape = circle
		soldier.add_child(cs)
		var rect := ColorRect.new()
		rect.size = Vector2(16.0, 16.0)
		rect.position = Vector2(-8.0, -8.0)
		rect.color = Color(0.8, 0.4, 0.2, 1.0)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		soldier.add_child(rect)
		squad.add_child(soldier)
		soldier.add_to_group("player_units")
		var weapon: WeaponComponent = soldier.get_node_or_null("WeaponComponent")
		if weapon == null:
			weapon = WeaponComponent.new()
			weapon.name = "WeaponComponent"
			soldier.add_child(weapon)
		weapon.attack_range = 550.0
		weapon.attack_damage = 45
		weapon.is_anti_tank = true
	get_tree().current_scene.call_deferred("add_child", squad)

func _spawn_vehicle() -> void:
	var vehicle := VehicleUnit.new()
	vehicle.position = _get_free_spawn_pos()
	vehicle.is_enemy = false
	get_tree().current_scene.call_deferred("add_child", vehicle)

func _spawn_drone() -> void:
	var drone := DroneUnit.new()
	drone.position = _get_free_spawn_pos()
	drone.drone_type = DroneUnit.DroneType.FPV_KAMIKAZE
	drone.is_enemy = false
	get_tree().current_scene.call_deferred("add_child", drone)

func _spawn_ew_vehicle() -> void:
	var vehicle := VehicleUnit.new()
	vehicle.position = _get_free_spawn_pos()
	vehicle.is_enemy = false
	vehicle.is_ew_jammer = true
	get_tree().current_scene.call_deferred("add_child", vehicle)


func _grant_veteran_xp(squad: Node) -> void:
	if not is_instance_valid(squad):
		return
	var soldiers: Array = squad.get("soldiers")
	if soldiers == null:
		return
	for s in soldiers:
		if is_instance_valid(s):
			var vc: VeterancyComponent = s.get_node_or_null("VeterancyComponent") as VeterancyComponent
			if vc != null:
				vc.add_xp(100)
