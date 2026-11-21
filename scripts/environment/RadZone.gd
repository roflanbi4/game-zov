class_name RadZone extends Area2D

var _accum: float = 0.0

func _ready() -> void:
	add_to_group("mission_cleanup")

func _process(delta: float) -> void:
	_accum += 3.0 * delta
	if _accum >= 1.0:
		_accum = 0.0
		for body in get_overlapping_bodies():
			var health: HealthComponent = body.get_node_or_null("HealthComponent") as HealthComponent
			if health and is_instance_valid(body):
				health.take_damage(3)