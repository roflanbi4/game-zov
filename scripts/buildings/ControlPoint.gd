class_name ControlPoint
extends Area2D

enum Owner { NONE = 0, PLAYER = 1, ENEMY = 2 }

@export var capture_radius: float = 80.0
@export var capture_time: float = 5.0
@export var capture_point_income: float = 5.0
@export var spawn_position: Vector2 = Vector2(200, 400)


var point_owner: int = Owner.NONE
var capture_timer: float = 0.0
var is_capturing: bool = false

var player_units_inside: int = 0
var enemy_units_inside: int = 0

var indicator: ColorRect
var _progress_bar: ColorRect

signal captured(new_owner: int)

func _ready() -> void:
	monitoring = true
	monitorable = false
	add_to_group("control_points")
	
	if get_node_or_null("CollisionShape2D") == null:
		var cs := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = capture_radius
		cs.shape = circle
		add_child(cs)
	
	if get_node_or_null("Indicator") == null:
		var rect := ColorRect.new()
		rect.size = Vector2(32.0, 32.0)
		rect.position = Vector2(-16.0, -16.0)
		rect.color = Color.GRAY
		rect.name = "Indicator"
		add_child(rect)
	indicator = get_node("Indicator")
	
	# РџСЂРѕРіСЂРµСЃСЃ-Р±Р°СЂ Р·Р°С…РІР°С‚Р° (РЅР°Рґ РёРЅРґРёРєР°С‚РѕСЂРѕРј, 0в†’40 px)
	var pb := ColorRect.new()
	pb.name = "CaptureProgress"
	pb.size = Vector2(0.0, 4.0)
	pb.position = Vector2(0.0, -16.0)
	pb.color = Color.GREEN
	add_child(pb)
	_progress_bar = pb
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

var _income_timer: float = 0.0
var _reinforce_timer: float = 0.0

func _process(delta: float) -> void:
	_update_capture_state()
	if is_capturing:
		capture_timer = minf(capture_time, capture_timer + delta)
		# РћР±РЅРѕРІР»СЏРµРј РїСЂРѕРіСЂРµСЃСЃ-Р±Р°СЂ
		var progress: float = capture_timer / capture_time
		_progress_bar.size = Vector2(40.0 * progress, 4.0)
		_progress_bar.position = Vector2(-20.0, -16.0)
		if capture_timer >= capture_time:
			capture_timer = 0.0
			is_capturing = false
			point_owner = current_captor()
			_update_indicator()
			_progress_bar.size = Vector2(0.0, 4.0)
			captured.emit(point_owner)
	
	if point_owner == Owner.PLAYER:
		_income_timer += delta
		_reinforce_timer += delta
		if _income_timer >= 1.0:
			_income_timer -= 1.0
			var eco: EconomyManager = get_tree().get_first_node_in_group("economy") as EconomyManager
			if eco != null:
				eco.add_sp(int(capture_point_income))

		if _reinforce_timer >= 3.0:
			_reinforce_timer -= 3.0
			var eco2: EconomyManager = get_tree().get_first_node_in_group("economy") as EconomyManager
			if eco2 != null and eco2.get_sp() >= 35:
				for sq in get_tree().get_nodes_in_group("player_squads"):
					if not is_instance_valid(sq):
						continue
					var sq_soldiers: Array = sq.get("soldiers")
					if sq_soldiers == null or sq_soldiers.size() >= 3 or sq_soldiers.is_empty():
						continue
					var alive_leader: Node2D = null
					for m in sq_soldiers:
						if is_instance_valid(m) and m is Node2D:
							alive_leader = m as Node2D
							break
					if alive_leader == null:
						continue
					if alive_leader.global_position.distance_to(global_position) <= capture_radius + 35.0:
						if eco2.spend_sp(35):
							var s := Soldier.new()
							s.name = "Soldier_Reinforce_" + str(randi())
							var nav := NavigationAgent2D.new()
							nav.name = "NavigationAgent2D"
							s.add_child(nav)
							var cs := CollisionShape2D.new()
							var circ := CircleShape2D.new()
							circ.radius = 6.0
							cs.shape = circ
							s.add_child(cs)
							var rect := ColorRect.new()
							rect.size = Vector2(16.0, 16.0)
							rect.position = Vector2(-8.0, -8.0)
							rect.color = Color(0.2, 0.9, 0.3, 1.0)
							rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
							s.add_child(rect)
							s.add_to_group("player_units")
							sq.add_child(s)
							s.global_position = alive_leader.global_position + Vector2(randf_range(-16.0, 16.0), randf_range(-16.0, 16.0))
							sq_soldiers.append(s)
						break



func _on_body_entered(_body: Node2D) -> void:
	_update_capture_state()

func _on_body_exited(_body: Node2D) -> void:
	_update_capture_state()

func _update_capture_state() -> void:
	player_units_inside = 0
	enemy_units_inside = 0
	for body in get_overlapping_bodies():
		if not is_instance_valid(body):
			continue
		if not (body is Node2D):
			continue
		if body.is_in_group("player_units"):
			player_units_inside += 1
		elif body.is_in_group("enemy_units"):
			enemy_units_inside += 1
	var total: int = player_units_inside + enemy_units_inside
	if total == 0:
		is_capturing = false
		capture_timer = 0.0
		_update_indicator()
		_progress_bar.size = Vector2(0.0, 4.0)
		return

	# Р•СЃР»Рё С‚РѕС‡РєР° СѓР¶Рµ Р·Р°С…РІР°С‡РµРЅР° СЌС‚РѕР№ СЃС‚РѕСЂРѕРЅРѕР№ вЂ” РЅРµ РЅР°С‡РёРЅР°РµРј Р·Р°С…РІР°С‚ Р·Р°РЅРѕРІРѕ
	if point_owner == Owner.PLAYER and player_units_inside > 0 and enemy_units_inside == 0:
		is_capturing = false
		capture_timer = 0.0
		_progress_bar.size = Vector2(0.0, 4.0)
		return
	if point_owner == Owner.ENEMY and enemy_units_inside > 0 and player_units_inside == 0:
		is_capturing = false
		capture_timer = 0.0
		_progress_bar.size = Vector2(0.0, 4.0)
		return

	if player_units_inside > 0 and enemy_units_inside == 0:
		is_capturing = true
		# РЅРµ РєСЂР°СЃРёРј РѕСЃРЅРѕРІРЅРѕР№ РєРІР°РґСЂР°С‚ РґРѕ Р·Р°РІРµСЂС€РµРЅРёСЏ Р·Р°С…РІР°С‚Р°
	elif enemy_units_inside > 0 and player_units_inside == 0:
		is_capturing = true
	else:
		is_capturing = false
		capture_timer = 0.0
		_progress_bar.size = Vector2(0.0, 4.0)

func current_captor() -> int:
	if player_units_inside > 0 and enemy_units_inside == 0:
		return Owner.PLAYER
	elif enemy_units_inside > 0 and player_units_inside == 0:
		return Owner.ENEMY
	return Owner.NONE

func _update_indicator() -> void:
	match point_owner:
		Owner.PLAYER:
			indicator.color = Color.BLUE
		Owner.ENEMY:
			indicator.color = Color.RED
		_:
			indicator.color = Color.GRAY
