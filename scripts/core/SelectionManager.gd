extends Node2D

@export var selection_color: Color = Color(0.0, 1.0, 0.0, 0.25)
@export var border_color: Color = Color(0.0, 1.0, 0.0, 0.9)
@export var highlight_color: Color = Color(1.0, 1.0, 0.0, 1.0)

var is_selecting: bool = false
var selection_start: Vector2 = Vector2.ZERO
var selection_end: Vector2 = Vector2.ZERO
var selected_units: Array[CharacterBody2D] = []
var selected_squads: Array = []

signal selection_changed(selected_units: Array[CharacterBody2D], selected_squads: Array)

func _ready() -> void:
	z_index = 100

	# Тестовый спавн: техника, дрон, аномалия, артефакт
	var vehicle := VehicleUnit.new()
	vehicle.name = "TestVehicle"
	vehicle.position = Vector2(350, 500)
	vehicle.is_enemy = false
	get_parent().call_deferred("add_child", vehicle)

	var drone := DroneUnit.new()
	drone.name = "TestDrone"
	drone.position = Vector2(380, 520)
	drone.drone_type = DroneUnit.DroneType.FPV_KAMIKAZE
	drone.is_enemy = false
	get_parent().call_deferred("add_child", drone)

	var anomaly := AnomalyZone.new()
	anomaly.name = "TestAnomaly"
	anomaly.position = Vector2(550, 550)
	anomaly.anomaly_type = AnomalyZone.AnomalyType.VORTEX
	get_parent().call_deferred("add_child", anomaly)

	var artifact := ArtifactPickup.new()
	artifact.name = "TestArtifact"
	artifact.position = Vector2(450, 550)
	artifact.buff_type = ArtifactPickup.BuffType.SPEED
	get_parent().call_deferred("add_child", artifact)
	
	# Step 6: Economy, HUD и контрольные точки (программно, без .tscn)
	var eco := EconomyManager.new()
	eco.name = "EconomyManager"
	get_parent().call_deferred("add_child", eco)
	
	var hud := GameHUD.new()
	hud.name = "GameHUD"
	get_parent().call_deferred("add_child", hud)
	
	for i in range(2):
		var cp := ControlPoint.new()
		cp.name = "ControlPoint_" + str(i)
		cp.position = Vector2(400 + i * 300, 300)
		get_parent().call_deferred("add_child", cp)

func _process(_delta: float) -> void:
	if is_selecting:
		selection_end = get_global_mouse_position()
		queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			is_selecting = true
			selection_start = get_global_mouse_position()
			selection_end = selection_start
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			is_selecting = false
			_select_units_in_box()
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_issue_move_command(get_global_mouse_position())

func _draw() -> void:
	if is_selecting:
		var rect: Rect2 = Rect2(selection_start.min(selection_end), (selection_start - selection_end).abs())
		draw_rect(rect, selection_color, true)
		draw_rect(rect, border_color, false, 2.0)

func _select_units_in_box() -> void:
	var rect: Rect2 = Rect2(selection_start.min(selection_end), (selection_start - selection_end).abs())
	rect = rect.grow(12.0)
	
	for unit in selected_units:
		if is_instance_valid(unit):
			unit.modulate = Color.WHITE
	selected_units.clear()
	selected_squads.clear()
	
	var squads: Array = get_tree().get_nodes_in_group("player_squads")
	for squad_node in squads:
		var squad = squad_node
		if not is_instance_valid(squad):
			continue
		var squad_selected: bool = false
		for soldier in squad.soldiers:
			if not is_instance_valid(soldier):
				continue
			if rect.has_point(soldier.global_position):
				squad_selected = true
				break
		if squad_selected:
			selected_squads.append(squad)
			for soldier in squad.soldiers:
				if is_instance_valid(soldier):
					soldier.modulate = highlight_color
					selected_units.append(soldier)
	
	# Выделение одиночной техники и дронов
	var vehicles: Array = get_tree().get_nodes_in_group("player_vehicles")
	for vehicle in vehicles:
		if is_instance_valid(vehicle) and rect.has_point(vehicle.global_position):
			selected_units.append(vehicle)
			vehicle.modulate = highlight_color

	var drones: Array = get_tree().get_nodes_in_group("player_drones")
	for drone in drones:
		if is_instance_valid(drone) and rect.has_point(drone.global_position):
			selected_units.append(drone)
			drone.modulate = highlight_color

	selection_changed.emit(selected_units, selected_squads)

func _issue_move_command(target: Vector2) -> void:
	for squad in selected_squads:
		if is_instance_valid(squad):
			squad.move_squad(target)
	for unit in selected_units:
		if is_instance_valid(unit) and (unit.is_in_group("player_vehicles") or unit.is_in_group("player_drones")) and unit.has_method("set_destination"):
			unit.set_destination(target)
