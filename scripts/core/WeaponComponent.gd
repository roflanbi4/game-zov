class_name WeaponComponent
extends Node2D

@export var attack_range: float = 400.0
@export var attack_damage: int = 25
@export var attack_cooldown: float = 1.0
@export var projectile_speed: float = 600.0
@export var target_group: String = "enemy_units"
@export var burst_enabled: bool = true

var detection_area: Area2D
var muzzle: Node2D
var cooldown_timer: float = 0.0
var current_target: Node2D = null
var _burst_count: int = 0
var _burst_timer: float = 0.0

func _ready() -> void:
	detection_area = get_node_or_null("DetectionArea")
	if detection_area == null:
		detection_area = Area2D.new()
		detection_area.name = "DetectionArea"
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = attack_range
		shape.shape = circle
		detection_area.add_child(shape)
		add_child(detection_area)
	
	muzzle = get_node_or_null("Muzzle")
	if muzzle == null:
		muzzle = Node2D.new()
		muzzle.name = "Muzzle"
		add_child(muzzle)

func _process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
	if _burst_timer > 0.0:
		_burst_timer -= delta
	var desired_radius: float = attack_range
	var fog: Node = get_tree().get_first_node_in_group("fog_of_war")
	var is_night: bool = fog != null and fog.get("is_night") == true
	if is_night and target_group == "player_units":
		desired_radius = maxf(attack_range, 450.0)
	var shape_node: CollisionShape2D = detection_area.get_child(0) as CollisionShape2D
	if shape_node != null:
		var circle: CircleShape2D = shape_node.shape as CircleShape2D
		if circle != null and circle.radius != desired_radius:
			circle.radius = desired_radius
	if current_target == null or not is_instance_valid(current_target):
		_find_target()
	if current_target != null:
		if not current_target.visible:
			current_target = null
			return
		if is_night:
			var shooter: Node2D = get_parent() as Node2D
			var allowed: float = _get_night_allowed_distance(shooter, current_target)
			if global_position.distance_to(current_target.global_position) > allowed:
				current_target = null
				return
		var dist_to_target: float = global_position.distance_to(current_target.global_position)
		if cooldown_timer <= 0.0:
			if burst_enabled and _burst_count < 3 and dist_to_target > 120.0 and dist_to_target <= 260.0:
				if _burst_timer <= 0.0:
					_shoot()
					_burst_count += 1
					_burst_timer = 0.13
					if _burst_count >= 3:
						_burst_count = 0
						_burst_timer = 0.0
						cooldown_timer = attack_cooldown
			elif dist_to_target <= 120.0:
				_shoot()
				cooldown_timer = randf_range(0.20, 0.34)
			elif dist_to_target > 260.0:
				_shoot()
				cooldown_timer = attack_cooldown * randf_range(0.9, 1.35)
			else:
				_shoot()
				cooldown_timer = attack_cooldown

func _get_night_allowed_distance(shooter: Node2D, target: Node2D) -> float:
	if target_group == "player_units":
		# Враги стреляют в игрока: фонарик игрока демаскирует на 450px, иначе 130px
		if target is Soldier:
			var flashlight: bool = bool(target.get("flashlight_on"))
			var has_nvg: bool = bool(target.get("has_nvg"))
			if flashlight and not has_nvg:
				return 450.0
		return 130.0
	else:
		# Игрок стреляет в врага: дистанция зависит от оснащения стрелка (shooter)
		if shooter is VehicleUnit:
			return attack_range  # техника — полный обзор
		if shooter is Soldier:
			var vc: VeterancyComponent = shooter.get_node_or_null("VeterancyComponent") as VeterancyComponent
			var rank: int = vc.rank if vc != null else VeterancyComponent.Rank.ROOKIE
			var has_nvg: bool = bool(shooter.get("has_nvg"))
			var flashlight: bool = bool(shooter.get("flashlight_on"))
			if rank >= VeterancyComponent.Rank.VETERAN:
				return attack_range  # тепловизор — полная дистанция
			if has_nvg:
				return 300.0  # ПНВ
			if flashlight:
				return 320.0  # фонарик демаскирует
			return 140.0  # новичок без ПНВ и с выключенным фонариком
	return attack_range

func _find_target() -> void:
	var bodies: Array = detection_area.get_overlapping_bodies()
	var nearest: Node2D = null
	var nearest_dist: float = INF
	var fog: Node = get_tree().get_first_node_in_group("fog_of_war")
	var is_night: bool = fog != null and fog.get("is_night") == true
	var shooter: Node2D = get_parent() as Node2D
	for body in bodies:
		if not (body is Node2D):
			continue
		if not (target_group in body.get_groups()):
			continue
		if not body.visible:
			continue
		var dist: float = global_position.distance_to(body.global_position)
		var allowed: float = attack_range
		if is_night:
			if target_group == "player_units":
				if body is Soldier:
					var flashlight: bool = bool(body.get("flashlight_on"))
					var has_nvg: bool = bool(body.get("has_nvg"))
					if flashlight and not has_nvg:
						allowed = 450.0
					else:
						allowed = 130.0
			else:
				allowed = _get_night_allowed_distance(shooter, body)
		if dist <= allowed and dist < nearest_dist:
			nearest_dist = dist
			nearest = body
	current_target = nearest

func _shoot() -> void:
	if current_target == null:
		return
	var bullet := Node2D.new()
	var script_res := preload("res://scripts/core/Projectile.gd")
	bullet.set_script(script_res)
	bullet.set("shooter", get_parent())
	var rect := ColorRect.new()
	rect.size = Vector2(6, 6)
	rect.position = Vector2(-3, -3)
	rect.color = Color.YELLOW
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bullet.add_child(rect)
	bullet.global_position = muzzle.global_position
	get_tree().root.add_child(bullet)
	bullet.setup(current_target.global_position, projectile_speed, attack_damage, target_group)
	if has_meta("morale_penalty"):
		bullet.morale_penalty = int(get_meta("morale_penalty"))
