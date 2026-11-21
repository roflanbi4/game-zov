extends Node2D

@export var selection_color: Color = Color(0.0, 1.0, 0.0, 0.25)
@export var border_color: Color = Color(0.0, 1.0, 0.0, 0.9)
@export var highlight_color: Color = Color(1.0, 1.0, 0.0, 1.0)

var is_selecting: bool = false
var selection_start: Vector2 = Vector2.ZERO
var selection_end: Vector2 = Vector2.ZERO
var selected_units: Array[CharacterBody2D] = []
var selected_squads: Array = []
var control_groups: Dictionary = {}
var attack_move_mode: bool = false

signal selection_changed(selected_units: Array[CharacterBody2D], selected_squads: Array)

func _ready() -> void:
	z_index = 100

	# Step 7: MissionManager — меню выбора миссий и сборка миссий (программно)
	var mm := MissionManager.new()
	mm.name = "MissionManager"
	get_parent().call_deferred("add_child", mm)

func _process(_delta: float) -> void:
	if is_selecting:
		selection_end = get_global_mouse_position()
		queue_redraw()

func _input(event: InputEvent) -> void:
	if get_viewport().gui_get_hovered_control() != null:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_Q:
			attack_move_mode = true
			_notify("Режим атаки-движения: кликните ПКМ")
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_H:
			_issue_hold()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_R:
			_issue_retreat()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var group_id: int = event.keycode - KEY_1 + 1
			if event.ctrl_pressed:
				_assign_control_group(group_id)
			else:
				_select_control_group(group_id)
			get_viewport().set_input_as_handled()
			return
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
			if attack_move_mode:
				_issue_attack_move(get_global_mouse_position())
				attack_move_mode = false
			else:
				_issue_move_command(get_global_mouse_position())

func _draw() -> void:
	if is_selecting:
		var rect: Rect2 = Rect2(selection_start.min(selection_end), (selection_start - selection_end).abs())
		draw_rect(rect, selection_color, true)
		draw_rect(rect, border_color, false, 2.0)

func _clear_selection() -> void:
	for unit in selected_units:
		if is_instance_valid(unit):
			unit.modulate = Color.WHITE
			var visual: CanvasItem = unit.get_node_or_null("ColorRect") as CanvasItem
			if visual != null:
				visual.modulate = Color.WHITE
	selected_units.clear()
	selected_squads.clear()

func _assign_control_group(group_id: int) -> void:
	var members: Array = []
	for unit in selected_units:
		if is_instance_valid(unit):
			members.append(unit)
	for squad in selected_squads:
		if is_instance_valid(squad):
			members.append(squad)
	control_groups[group_id] = members
	var hud: Node = get_tree().get_first_node_in_group("game_hud")
	if hud != null and hud.has_method("_show_notification"):
		hud.call("_show_notification", "Группа " + str(group_id) + " сохранена")

func _select_control_group(group_id: int) -> void:
	if not control_groups.has(group_id):
		return
	_clear_selection()
	var members: Array = control_groups[group_id]
	var valid_members: Array = []
	for member in members:
		if not is_instance_valid(member):
			continue
		valid_members.append(member)
		if member is SquadController:
			if member not in selected_squads:
				selected_squads.append(member)
			for soldier in member.soldiers:
				if is_instance_valid(soldier):
					selected_units.append(soldier)
					_highlight_unit(soldier)
		elif member is Node2D:
			selected_units.append(member)
			_highlight_unit(member)
	control_groups[group_id] = valid_members
	selection_changed.emit(selected_units, selected_squads)

func _highlight_unit(unit: Node2D) -> void:
	unit.modulate = Color.WHITE
	var visual: CanvasItem = unit.get_node_or_null("ColorRect") as CanvasItem
	if visual != null:
		visual.modulate = highlight_color

func _select_units_in_box() -> void:
	var rect: Rect2 = Rect2(selection_start.min(selection_end), (selection_start - selection_end).abs())
	rect = rect.grow(12.0)
	
	_clear_selection()
	
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
					var visual: CanvasItem = soldier.get_node_or_null("ColorRect") as CanvasItem
					if visual != null:
						visual.modulate = highlight_color
					soldier.modulate = Color.WHITE
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

func _issue_hold() -> void:
	for squad in selected_squads:
		if is_instance_valid(squad) and squad.has_method("hold"):
			squad.hold()
	for unit in selected_units:
		if is_instance_valid(unit) and not (unit is Soldier) and unit.has_method("hold"):
			unit.hold()
	_notify("Удержать позицию")

func _issue_retreat() -> void:
	var retreat_target: Vector2 = _nearest_friendly_rally_point()
	for squad in selected_squads:
		if is_instance_valid(squad) and squad.has_method("move_squad"):
			squad.move_squad(retreat_target)
	for unit in selected_units:
		if is_instance_valid(unit) and not (unit is Soldier) and unit.has_method("set_destination"):
			unit.set_destination(retreat_target)
	_notify("Отступление")

func _issue_attack_move(target: Vector2) -> void:
	for squad in selected_squads:
		if is_instance_valid(squad):
			if squad.has_method("set_attack_move"):
				squad.set_attack_move(true)
			if squad.has_method("move_squad"):
				squad.move_squad(target)
	for unit in selected_units:
		if is_instance_valid(unit) and not (unit is Soldier):
			if unit.has_method("set_attack_move"):
				unit.set_attack_move(true)
			if unit.has_method("set_destination"):
				unit.set_destination(target)
	_notify("Атака-движение")

func _nearest_friendly_rally_point() -> Vector2:
	var fallback: Vector2 = Vector2(200.0, 400.0)
	var origin: Vector2 = fallback
	if not selected_units.is_empty() and is_instance_valid(selected_units[0]):
		origin = selected_units[0].global_position
	var best: Vector2 = fallback
	var best_dist: float = INF
	for cp in get_tree().get_nodes_in_group("control_points"):
		if not is_instance_valid(cp):
			continue
		if int(cp.get("point_owner")) != 1:
			continue
		var cp_pos: Vector2 = cp.global_position
		var dist: float = origin.distance_to(cp_pos)
		if dist < best_dist:
			best_dist = dist
			best = cp_pos
	return best

func _notify(text: String) -> void:
	var hud: Node = get_tree().get_first_node_in_group("game_hud")
	if hud != null and hud.has_method("_show_notification"):
		hud.call("_show_notification", text)

func issue_hold() -> void:
	_issue_hold()

func issue_retreat() -> void:
	_issue_retreat()
