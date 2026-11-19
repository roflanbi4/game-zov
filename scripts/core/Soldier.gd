class_name Soldier
extends CharacterBody2D

@export var move_speed: float = 180.0
@export var formation_offset: Vector2 = Vector2.ZERO

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
var health_component: HealthComponent
var weapon: WeaponComponent
var morale_component: MoraleComponent
var veterancy_component: VeterancyComponent

var flashlight_on: bool = true
var has_nvg: bool = false
var _last_facing: Vector2 = Vector2.RIGHT
var target_position: Vector2 = Vector2.ZERO
var squad_controller: Node2D = null

func _ready() -> void:
	set_physics_process(false)
	
	health_component = get_node_or_null("HealthComponent")
	if health_component == null:
		health_component = HealthComponent.new()
		health_component.name = "HealthComponent"
		add_child(health_component)
	health_component.died.connect(_on_health_died)
	
	weapon = get_node_or_null("WeaponComponent")
	if weapon == null:
		weapon = WeaponComponent.new()
		weapon.name = "WeaponComponent"
		add_child(weapon)
	morale_component = get_node_or_null("MoraleComponent")
	if morale_component == null:
		morale_component = MoraleComponent.new()
		morale_component.name = "MoraleComponent"
		add_child(morale_component)

	veterancy_component = get_node_or_null("VeterancyComponent")
	if veterancy_component == null:
		veterancy_component = VeterancyComponent.new()
		veterancy_component.name = "VeterancyComponent"
		add_child(veterancy_component)

	var cone := Polygon2D.new()
	cone.name = "FlashlightCone"
	cone.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(320.0, 0.0).rotated(deg_to_rad(-25.0)),
		Vector2(320.0, 0.0).rotated(deg_to_rad(25.0))
	])
	cone.color = Color(1.0, 0.95, 0.7, 0.25)
	cone.visible = false
	add_child(cone)


	
	var parent = get_parent()
	if parent is Node2D:
		squad_controller = parent
		var groups = parent.get_groups()
		if "enemy_squads" in groups:
			add_to_group("enemy_units")
			weapon.target_group = "player_units"
		else:
			add_to_group("player_units")
			weapon.target_group = "enemy_units"

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
	_last_facing = dir
	move_and_slide()

func _on_health_died(soldier: Node2D) -> void:
	set_physics_process(false)
	if squad_controller != null:
		squad_controller.call("on_soldier_died", soldier)

func _process(_delta: float) -> void:
	var cone: Polygon2D = get_node_or_null("FlashlightCone") as Polygon2D
	if cone == null:
		return
	var fog: FogOfWarManager = get_tree().get_first_node_in_group("fog_of_war") as FogOfWarManager
	var is_night: bool = fog != null and fog.is_night
	var rank: int = 0
	if veterancy_component != null:
		rank = veterancy_component.rank

	# Разворот к цели или по вектору движения
	if weapon != null and weapon.current_target != null and is_instance_valid(weapon.current_target):
		_last_facing = (weapon.current_target.global_position - global_position).normalized()
	elif velocity.length() > 1.0:
		_last_facing = velocity.normalized()

	# Авто-выключение фонарика при ПНВ или ранге Veteran+
	if has_nvg or rank >= VeterancyComponent.Rank.VETERAN:
		if flashlight_on:
			flashlight_on = false

	# Видимость конуса фонарика: только Rookie без ПНВ, только ночь, только_player_units, только flashlight_on
	cone.visible = is_night and rank == VeterancyComponent.Rank.ROOKIE and not has_nvg and is_in_group("player_units") and flashlight_on
	cone.rotation = _last_facing.angle()
