class_name DroneUnit
extends CharacterBody2D

enum DroneType { RECON = 0, FPV_KAMIKAZE = 1 }

@export var drone_type: int = DroneType.RECON
@export var is_enemy: bool = false
@export var max_hp: int = 30
@export var move_speed: float = 260.0
@export var explosion_radius: float = 90.0
@export var explosion_damage: int = 150
@export var vehicle_damage: int = 350

var current_hp: int
var target_position: Vector2 = Vector2.ZERO
var disabled: bool = false
var _exploded: bool = false

func _ready() -> void:
	if is_enemy:
		add_to_group("enemy_drones")
		add_to_group("enemy_units")
	else:
		add_to_group("player_drones")
		add_to_group("player_units")

	collision_mask = 0

	if get_node_or_null("CollisionShape2D") == null:
		var cs := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 8.0
		cs.shape = circle
		add_child(cs)

	if get_node_or_null("ColorRect") == null:
		var rect := ColorRect.new()
		rect.size = Vector2(12.0, 12.0)
		rect.position = Vector2(-6.0, -6.0)
		rect.color = Color(0.9, 0.2, 0.2, 1.0) if is_enemy else Color(0.95, 0.9, 0.2, 1.0)
		add_child(rect)

	current_hp = max_hp
	set_physics_process(false)

func set_destination(destination: Vector2) -> void:
	target_position = destination
	set_physics_process(true)

func _physics_process(_delta: float) -> void:
	if disabled:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if target_position == Vector2.ZERO:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var to_target: Vector2 = target_position - global_position
	if drone_type == DroneType.FPV_KAMIKAZE:
		if _check_detonation():
			_explode()
			return
		if to_target.length() <= 20.0:
			_explode()
			return

	if to_target.length() < 8.0:
		velocity = Vector2.ZERO
		move_and_slide()
		set_physics_process(false)
		return

	velocity = to_target.normalized() * move_speed
	move_and_slide()

func _check_detonation() -> bool:
	for group in _target_groups():
		for node in get_tree().get_nodes_in_group(group):
			if is_instance_valid(node) and node != self:
				if global_position.distance_to(node.global_position) <= 20.0:
					return true
	return false

func _target_groups() -> Array[String]:
	if is_enemy:
		return ["player_units", "player_vehicles"]
	return ["enemy_units", "enemy_vehicles"]

func take_damage(amount: int) -> void:
	current_hp -= amount
	if current_hp <= 0:
		current_hp = 0
		if drone_type == DroneType.FPV_KAMIKAZE and not _exploded:
			_explode()
		else:
			queue_free()

func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	for group in _target_groups():
		for node in get_tree().get_nodes_in_group(group):
			if not is_instance_valid(node) or node == self:
				continue
			if global_position.distance_to(node.global_position) > explosion_radius:
				continue
			var dmg: int = vehicle_damage if node.is_in_group("player_vehicles") or node.is_in_group("enemy_vehicles") else explosion_damage
			if node.has_method("take_damage"):
				node.take_damage(dmg)
			else:
				var health: HealthComponent = node.get_node_or_null("HealthComponent") as HealthComponent
				if health != null:
					health.take_damage(dmg)
	queue_free()