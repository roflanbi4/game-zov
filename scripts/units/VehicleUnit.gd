class_name VehicleUnit
extends CharacterBody2D

@export var is_enemy: bool = false
@export var max_hp: int = 300
@export var armor: float = 0.35
@export var move_speed: float = 120.0
@export var attack_range: float = 450.0
@export var attack_damage: int = 40
@export var attack_cooldown: float = 1.2
@export var is_ew_jammer: bool = false

var current_hp: int
var _ew_timer: float = 0.0
var target_position: Vector2 = Vector2.ZERO

var health_component: HealthComponent
var weapon: WeaponComponent
var nav_agent: NavigationAgent2D

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
		if is_ew_jammer:
			rect.color = Color(0.2, 0.85, 0.9, 1.0)
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

	current_hp = max_hp
	set_physics_process(false)

func set_destination(destination: Vector2) -> void:
	target_position = destination
	nav_agent.set_target_position(destination)
	set_physics_process(true)

func _physics_process(_delta: float) -> void:
	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		move_and_slide()
		set_physics_process(false)
		return
	var next_pos: Vector2 = nav_agent.get_next_path_position()
	if next_pos == Vector2.ZERO:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var dir: Vector2 = (next_pos - global_position).normalized()
	velocity = dir * move_speed
	move_and_slide()

func _process(delta: float) -> void:
	if is_ew_jammer:
		_ew_timer += delta
		if _ew_timer >= 0.5:
			_ew_timer = 0.0
			_jam_drones()

func _jam_drones() -> void:
	var drones: Array = get_tree().get_nodes_in_group("enemy_drones")
	for drone in drones:
		if is_instance_valid(drone) and drone is Node2D:
			if global_position.distance_to(drone.global_position) <= 250.0:
				drone.queue_free()

func take_damage(amount: int) -> void:
	var reduced: int = int(amount * (1.0 - armor))
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