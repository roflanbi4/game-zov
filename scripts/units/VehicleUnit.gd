class_name VehicleUnit
extends CharacterBody2D

@export var is_ew_jammer: bool = false
@export var is_enemy: bool = false
@export var max_hp: int = 300
@export var armor: float = 0.35
@export var move_speed: float = 120.0
@export var attack_range: float = 450.0
@export var attack_damage: int = 40
@export var attack_cooldown: float = 1.2

var target_position: Vector2 = Vector2.ZERO
var attack_move: bool = false
var hold_mode: bool = false

var health_component: HealthComponent
var weapon: WeaponComponent
var nav_agent: NavigationAgent2D
var _base_speed: float = 0.0
var _speed_mults: Dictionary = {}

func _ready() -> void:
	z_index = 5
	if is_enemy:
		add_to_group("enemy_vehicles")
		add_to_group("enemy_units")
	else:
		add_to_group("player_vehicles")
		add_to_group("player_units")

	if get_node_or_null("CollisionShape2D") == null:
		var cs := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 14.0
		cs.shape = circle
		add_child(cs)

	if get_node_or_null("ColorRect") == null:
		var rect := ColorRect.new()
		rect.size = Vector2(28.0, 28.0)
		rect.position = Vector2(-14.0, -14.0)
		rect.color = Color(0.9, 0.2, 0.2, 1.0) if is_enemy else Color(0.2, 0.9, 0.3, 1.0)
		add_child(rect)

	health_component = HealthComponent.new()
	health_component.name = "HealthComponent"
	health_component.max_hp = max_hp
	health_component.current_hp = max_hp
	add_child(health_component)
	health_component.died.connect(_on_died)

	weapon = WeaponComponent.new()
	weapon.name = "WeaponComponent"
	weapon.attack_range = attack_range
	weapon.attack_damage = attack_damage
	weapon.attack_cooldown = attack_cooldown
	weapon.target_group = "enemy_units" if not is_enemy else "player_units"
	add_child(weapon)

	nav_agent = NavigationAgent2D.new()
	nav_agent.name = "NavigationAgent2D"
	add_child(nav_agent)

	_base_speed = move_speed
	set_physics_process(false)

func set_destination(destination: Vector2) -> void:
	target_position = destination
	nav_agent.set_target_position(destination)
	hold_mode = false
	attack_move = false
	set_physics_process(true)

func hold() -> void:
	hold_mode = true
	attack_move = false
	target_position = global_position
	if nav_agent != null:
		nav_agent.set_target_position(global_position)
	velocity = Vector2.ZERO

func stop() -> void:
	hold_mode = false
	attack_move = false
	target_position = global_position
	if nav_agent != null:
		nav_agent.set_target_position(global_position)
	velocity = Vector2.ZERO

func set_attack_move(enabled: bool) -> void:
	attack_move = enabled

func _process(_delta: float) -> void:
	if is_ew_jammer:
		var target_group: String = "enemy_drones" if not is_enemy else "player_drones"
		for d in get_tree().get_nodes_in_group(target_group):
			if is_instance_valid(d) and d is Node2D:
				if global_position.distance_to((d as Node2D).global_position) <= 220.0:
					d.set("disabled", true)

func _physics_process(_delta: float) -> void:
	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		move_and_slide()
		set_physics_process(false)
		return
	if attack_move and weapon != null and is_instance_valid(weapon) and weapon.current_target != null and is_instance_valid(weapon.current_target):
		if global_position.distance_to(weapon.current_target.global_position) <= weapon.attack_range:
			velocity = Vector2.ZERO
			move_and_slide()
			return
	var next_pos: Vector2 = nav_agent.get_next_path_position()
	if next_pos == Vector2.ZERO:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var dir: Vector2 = (next_pos - global_position).normalized()
	velocity = dir * move_speed
	move_and_slide()

func take_damage(amount: int, is_at: bool = false) -> void:
	var dmg_after_armor: float = float(amount) * (1.0 - armor)
	if not is_at:
		dmg_after_armor *= 0.15
	var reduced: int = int(dmg_after_armor)
	if amount > 0 and reduced < 1:
		reduced = 1
	if health_component != null:
		health_component.take_damage(reduced)


func _on_died(_soldier: Node2D) -> void:
	if is_enemy and randf() < 0.60:
		call_deferred("_spawn_loot", global_position)
	queue_free()

func _spawn_loot(pos: Vector2) -> void:
	var crate := LootCrate.new()
	crate.loot_type = randi() % 3
	get_tree().current_scene.add_child(crate)
	crate.global_position = pos

func set_speed_multiplier(source: String, mult: float) -> void:
	if _base_speed <= 0.0:
		_base_speed = move_speed
	if is_equal_approx(mult, 1.0):
		_speed_mults.erase(source)
	else:
		_speed_mults[source] = mult
	var final_speed: float = _base_speed
	for v in _speed_mults.values():
		final_speed *= float(v)
	move_speed = final_speed
