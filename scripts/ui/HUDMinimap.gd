class_name HUDMinimap extends Control

const _CFG := preload("res://scripts/core/GameConfig.gd")

const MAP_UI_W: float = 240.0
const MAP_UI_H: float = 135.0

func _ready() -> void:
	custom_minimum_size = Vector2(MAP_UI_W, MAP_UI_H)
	size = Vector2(MAP_UI_W, MAP_UI_H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.08, 0.1, 0.08, 0.88), true)
	draw_rect(rect, Color(0.45, 0.5, 0.45, 0.9), false, 1.5)

	# Дорога по центру
	var road_y: float = size.y * 0.5
	draw_line(Vector2(0.0, road_y), Vector2(size.x, road_y), Color(0.6, 0.6, 0.6, 0.6), 1.0)

	var cam: Camera2D = get_tree().get_first_node_in_group("rts_camera") as Camera2D

	# Точки контроля
	for cp in get_tree().get_nodes_in_group("control_points"):
		if not is_instance_valid(cp) or not (cp is Node2D):
			continue
		var owner_val: int = int(cp.get("point_owner"))
		var color: Color = Color(0.5, 0.5, 0.5, 1.0)
		match owner_val:
			1:
				color = Color(0.2, 0.7, 1.0, 1.0)
			2:
				color = Color(1.0, 0.25, 0.25, 1.0)
			_:
				color = Color(0.5, 0.5, 0.5, 1.0)
		var mini_pos: Vector2 = _to_mini((cp as Node2D).global_position)
		draw_rect(Rect2(mini_pos - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), color)

	# Союзные юниты
	for g in ["player_units", "player_vehicles", "player_drones"]:
		for node in get_tree().get_nodes_in_group(g):
			if not is_instance_valid(node) or not (node is Node2D):
				continue
			var mini_pos: Vector2 = _to_mini((node as Node2D).global_position)
			draw_circle(mini_pos, 2.5, Color(0.2, 0.7, 1.0, 1.0))

	# Видимые враги
	for g in ["enemy_units", "enemy_vehicles", "mutants"]:
		for node in get_tree().get_nodes_in_group(g):
			if not is_instance_valid(node) or not (node is Node2D):
				continue
			if not (node as Node).visible:
				continue
			var mini_pos: Vector2 = _to_mini((node as Node2D).global_position)
			draw_circle(mini_pos, 2.5, Color(1.0, 0.25, 0.25, 1.0))

	# Прямоугольник камеры
	if cam != null:
		var cam_size: Vector2 = cam.get_viewport_rect().size if cam.get_viewport() != null else Vector2(640.0, 360.0)
		var cam_mini: Vector2 = _to_mini(cam.global_position - cam_size * 0.5)
		var cam_mini_size: Vector2 = Vector2((cam_size.x / _CFG.MAP_WIDTH) * size.x, (cam_size.y / _CFG.MAP_HEIGHT) * size.y)
		draw_rect(Rect2(cam_mini, cam_mini_size), Color(1.0, 1.0, 1.0, 0.6), false, 1.0)

func _to_mini(world_pos: Vector2) -> Vector2:
	return Vector2((world_pos.x / _CFG.MAP_WIDTH) * size.x, (world_pos.y / _CFG.MAP_HEIGHT) * size.y)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var world_pos: Vector2 = _world_from_mini(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var cam: Camera2D = get_tree().get_first_node_in_group("rts_camera") as Camera2D
			if cam != null:
				cam.position = world_pos
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_send_selected_to(world_pos)
			accept_event()

func _world_from_mini(mini_pos: Vector2) -> Vector2:
	return Vector2((mini_pos.x / size.x) * _CFG.MAP_WIDTH, (mini_pos.y / size.y) * _CFG.MAP_HEIGHT)

func _send_selected_to(world_pos: Vector2) -> void:
	var sel_mgr: Node = get_tree().current_scene.get_node_or_null("SelectionManager")
	if sel_mgr == null:
		return
	var selected_squads: Array = sel_mgr.get("selected_squads")
	if selected_squads == null:
		return
	for sq in selected_squads:
		if not is_instance_valid(sq) or not (sq is Node2D):
			continue
		if sq.has_method("move_squad"):
			sq.move_squad(world_pos)
		elif sq.has_method("set_destination"):
			sq.set_destination(world_pos)
	var selected_units: Array = sel_mgr.get("selected_units")
	if selected_units == null:
		return
	for unit in selected_units:
		if not is_instance_valid(unit) or not (unit is Node2D):
			continue
		if unit.has_method("set_destination"):
			unit.set_destination(world_pos)
