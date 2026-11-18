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

signal captured(new_owner: int)

func _ready() -> void:
	monitoring = true
	monitorable = false
	
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
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

var _income_timer: float = 0.0

func _process(delta: float) -> void:
	if is_capturing:
		capture_timer = minf(capture_time, capture_timer + delta)
		if capture_timer >= capture_time:
			capture_timer = 0.0
			is_capturing = false
			point_owner = current_captor()
			_update_indicator()
			captured.emit(point_owner)
	
	if point_owner == Owner.PLAYER:
		_income_timer += delta
		if _income_timer >= 1.0:
			_income_timer -= 1.0
			var eco: EconomyManager = get_tree().get_first_node_in_group("economy") as EconomyManager
			if eco != null:
				eco.add_sp(int(capture_point_income))

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_units"):
		player_units_inside += 1
	elif body.is_in_group("enemy_units"):
		enemy_units_inside += 1
	_update_capture_state()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player_units"):
		player_units_inside = max(0, player_units_inside - 1)
	elif body.is_in_group("enemy_units"):
		enemy_units_inside = max(0, enemy_units_inside - 1)
	_update_capture_state()

func _update_capture_state() -> void:
	var total: int = player_units_inside + enemy_units_inside
	if total == 0:
		is_capturing = false
		capture_timer = 0.0
		indicator.color = Color.GRAY
		return
	
	if player_units_inside > 0 and enemy_units_inside == 0:
		is_capturing = true
		indicator.color = Color.BLUE
	elif enemy_units_inside > 0 and player_units_inside == 0:
		is_capturing = true
		indicator.color = Color.RED
	else:
		is_capturing = false
		capture_timer = 0.0
		indicator.color = Color.GRAY

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
