extends Node2D

@export var speed: float = 600.0
@export var damage: int = 25
@export var target_group: String = "enemy_units"
@export var morale_penalty: int = 0

var target_position: Vector2 = Vector2.ZERO
var active: bool = true
var shooter: Node2D = null

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
	var final_damage: float = float(damage)
	for obj in targets:
		if is_instance_valid(obj) and global_position.distance_to(obj.global_position) < 24.0:
			if obj is Soldier:
				var facing_variant: Variant = obj.get("_last_facing")
				if facing_variant is Vector2:
					var facing: Vector2 = facing_variant as Vector2
					var to_attacker: Vector2 = (global_position - obj.global_position).normalized()
					var dot: float = facing.dot(to_attacker)
					if dot < -0.5:
						final_damage *= 1.5
					elif dot < 0.2:
						final_damage *= 1.25
			var health: HealthComponent = obj.get_node_or_null("HealthComponent")
			if health:
				if obj.has_method("take_damage"):
					obj.take_damage(int(final_damage))
				else:
					health.take_damage(int(final_damage))
			if morale_penalty > 0:
				var morale: MoraleComponent = obj.get_node_or_null("MoraleComponent") as MoraleComponent
				if morale != null:
					morale.reduce_morale(float(morale_penalty))
			_award_xp()
			break
	queue_free()

func _award_xp() -> void:
	if shooter == null or not is_instance_valid(shooter):
		return
	var squad: Node = shooter.get("squad_controller")
	if squad != null and is_instance_valid(squad):
		var soldiers: Array = squad.get("soldiers")
		if soldiers != null:
			for s in soldiers:
				if is_instance_valid(s):
					var vet: VeterancyComponent = s.get_node_or_null("VeterancyComponent") as VeterancyComponent
					if vet != null:
						vet.add_xp(15)
			return
	var vet: VeterancyComponent = shooter.get_node_or_null("VeterancyComponent") as VeterancyComponent
	if vet != null:
		vet.add_xp(15)
