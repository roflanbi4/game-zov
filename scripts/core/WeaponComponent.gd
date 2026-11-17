class_name WeaponComponent
extends Node2D

@export var attack_range: float = 400.0
@export var attack_damage: int = 25
@export var attack_cooldown: float = 1.0
@export var projectile_speed: float = 600.0
@export var target_group: String = "enemy_units"

var detection_area: Area2D
var muzzle: Node2D
var cooldown_timer: float = 0.0
var current_target: Node2D = null

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
	if current_target == null or not is_instance_valid(current_target):
		_find_target()
	if current_target != null and cooldown_timer <= 0.0:
		_shoot()
		cooldown_timer = attack_cooldown

func _find_target() -> void:
	var bodies: Array = detection_area.get_overlapping_bodies()
	var nearest: Node2D = null
	var nearest_dist: float = attack_range
	for body in bodies:
		if body is Node2D and target_group in body.get_groups():
			var dist: float = global_position.distance_to(body.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = body
	current_target = nearest

func _shoot() -> void:
	if current_target == null:
		return
	var bullet := Node2D.new()
	var script_res := preload("res://scripts/core/Projectile.gd")
	bullet.set_script(script_res)
	var rect := ColorRect.new()
	rect.size = Vector2(6, 6)
	rect.position = Vector2(-3, -3)
	rect.color = Color.YELLOW
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bullet.add_child(rect)
	bullet.global_position = muzzle.global_position
	get_tree().root.add_child(bullet)
	bullet.setup(current_target.global_position, projectile_speed, attack_damage, target_group)
