extends Node2D

@export var speed: float = 600.0
@export var damage: int = 25
@export var target_group: String = "enemy_units"

var target_position: Vector2 = Vector2.ZERO
var active: bool = true

func setup(target: Vector2, projectile_speed: float, projectile_damage: int, projectile_target_group: String) -> void:
	target_position = target
	speed = projectile_speed
	damage = projectile_damage
	target_group = projectile_target_group

func _process(delta: float) -> void:
	if not active:
		return
	var dir: Vector2 = (target_position - global_position).normalized()
	global_position += dir * speed * delta
	if global_position.distance_to(target_position) < 10.0:
		_hit_target()
		active = false

func _hit_target() -> void:
	var targets: Array = get_tree().get_nodes_in_group(target_group)
	targets.append_array(get_tree().get_nodes_in_group("explosives"))
	for obj in targets:
		if is_instance_valid(obj) and global_position.distance_to(obj.global_position) < 24.0:
			var health: HealthComponent = obj.get_node_or_null("HealthComponent")
			if health:
				health.take_damage(damage)
			break
	queue_free()
